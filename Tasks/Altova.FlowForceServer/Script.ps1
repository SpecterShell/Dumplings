function Read-Installer {
  foreach ($Installer in $this.CurrentState.Installer) {
    $this.Log("Processing $($Installer.Architecture) installer", 'Verbose')

    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFileExtracted}" $InstallerFile '*.cab' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted '*.cab' | Get-Item -Force | Select-Object -First 1
    $InstallerFile2Extracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFile2Extracted}" $InstallerFile2 '*.msi' | Out-Host
    $InstallerFile3 = Join-Path $InstallerFile2Extracted '*.msi' | Get-Item -Force | Select-Object -First 1
    # Version
    $this.CurrentState.Version = $InstallerFile3 | Read-ProductVersionFromMsi
    # ProductCode
    $Installer.ProductCode = $InstallerFile3 | Read-ProductCodeFromMsi
    Remove-Item -Path $InstallerFile2Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
  }
}

function Get-ReleaseNotes {
  try {
    $Object3 = Invoke-WebRequest -Uri 'https://www.altova.com/releasenotes/getnotes' -Method Post -Body @{
      category = 'desktop'
      product  = 'FlowForce'
      version  = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '/v(\d+(r\d+)?(sp\d+)?)/').Groups[1].Value
    } | ConvertFrom-Html

    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $Object3.SelectNodes('/table/tbody/tr').ForEach({ "[$($_.SelectSingleNode('./td[@class="component"]').InnerText)] $($_.SelectSingleNode('./td[@class="summary"]').InnerText)" }) | Format-Text
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$Object1 = Invoke-WebRequest -Uri 'https://www.altova.com/thankyou?ProductCode=FS&EditionCode=Z&InstallerType=Product&Lang=multi&OperatingSystem=win32'

# Installer
$InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl -replace '\.exe$', '_x64.exe'
}

$Object2 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
# Hash
$this.CurrentState.Hash = $Object2.Headers.'x-amz-meta-sha256'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  $this.Message()
  if ($this.CurrentState.Version.Split('.')[0] -ne ($this.Config.WinGetIdentifier.Split('.') -match '20\d{2}')) {
    $this.Config.WinGetNewPackageIdentifier = $this.Config.WinGetIdentifier -replace '20\d{2}', $this.CurrentState.Version.Split('.')[0]
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'PackageName'
      Value  = { $_ -replace '20\d{2}', $this.CurrentState.Version.Split('.')[0] }
    }
  }
  $this.Submit()
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The hash is unchanged
if ($this.CurrentState.Hash -eq $this.LastState.Hash) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

switch -Regex ($this.Check()) {
  # Case 5: The hash and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    if ($this.CurrentState.Version.Split('.')[0] -ne ($this.Config.WinGetIdentifier.Split('.') -match '20\d{2}')) {
      $this.Config.WinGetNewPackageIdentifier = $this.Config.WinGetIdentifier -replace '20\d{2}', $this.CurrentState.Version.Split('.')[0]
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'PackageName'
        Value  = { $_ -replace '20\d{2}', $this.CurrentState.Version.Split('.')[0] }
      }
    }
    $this.Submit()
  }
  # Case 4: The hash has changed, but the version is not
  default {
    $this.Log('The hash has changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    if ($this.CurrentState.Version.Split('.')[0] -ne ($this.Config.WinGetIdentifier.Split('.') -match '20\d{2}')) {
      $this.Config.WinGetNewPackageIdentifier = $this.Config.WinGetIdentifier -replace '20\d{2}', $this.CurrentState.Version.Split('.')[0]
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'PackageName'
        Value  = { $_ -replace '20\d{2}', $this.CurrentState.Version.Split('.')[0] }
      }
    }
    $this.Submit()
  }
}
