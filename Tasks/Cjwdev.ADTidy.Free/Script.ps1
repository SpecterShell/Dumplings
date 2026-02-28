function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  $InstallerFileExtracted = New-TempFolder
  7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'ADTidyClient.exe' | Out-Host
  $InstallerFile2 = Join-Path $InstallerFileExtracted 'ADTidyClient.exe'
  $InstallerFile2Extracted = New-TempFolder
  Start-Process -FilePath $InstallerFile2 -ArgumentList @('/extract', $InstallerFile2Extracted) -Wait
  $InstallerFile3 = Join-Path $InstallerFile2Extracted 'ADTidyClient.msi'
  $InstallerFile4 = Join-Path $InstallerFile2Extracted 'ADTidyClient.x64.msi'
  # Version
  # $this.CurrentState.Version = $InstallerFile3 | Read-ProductVersionFromMsi
  $this.CurrentState.Version = $InstallerFile4 | Read-ProductVersionFromMsi
  # InstallerSha256
  $InstallerX86['InstallerSha256'] = $InstallerX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  # ProductCode
  $InstallerX86['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
  $InstallerX64['ProductCode'] = $InstallerFile4 | Read-ProductCodeFromMsi
  # AppsAndFeaturesEntries
  $InstallerX86['AppsAndFeaturesEntries'] = @(
    [ordered]@{
      UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
      InstallerType = 'msi'
    }
  )
  $InstallerX64['AppsAndFeaturesEntries'] = @(
    [ordered]@{
      UpgradeCode   = $InstallerFile4 | Read-UpgradeCodeFromMsi
      InstallerType = 'msi'
    }
  )
  Remove-Item -Path $InstallerFile2Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
  Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

function Get-ReleaseNotes {
  try {
    $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://cjwdev.com/Software/ADTidy/VersionHistory.txt').RawContentStream)

    while (-not $Object2.EndOfStream) {
      $String = $Object2.ReadLine()
      if ($String -match "^Version $([regex]::Escape($this.CurrentState.Version))$") {
        break
      }
    }
    if (-not $Object2.EndOfStream) {
      $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String -notmatch '^Version \d+(\.\d+)+$') {
          $ReleaseNotesObjects.Add($String -replace '^\t')
        } else {
          break
        }
      }
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesObjects | Format-Text
      }
    } else {
      $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$Prefix = 'https://cjwdev.com/Software/ADTidy/Download.html'
$Object1 = Invoke-WebRequest -Uri $Prefix

$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.zip') } catch {} }, 'First')[0].href | ConvertTo-Https
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.zip') } catch {} }, 'First')[0].href | ConvertTo-Https
}

$Object2 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
$ETag = $Object2.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The ETag is unchanged
if ($ETag -in $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (Global)", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

# Case 4: The ETag has changed, but the SHA256 is not
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The ETag has changed, but the SHA256 is not', 'Info')

  # ETag
  $this.CurrentState.ETag = $this.LastState.ETag + $ETag

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)

switch -Regex ($this.Check()) {
  # Case 6: The ETag, the SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 5: The ETag and the SHA256 have changed, but the version is not
  default {
    $this.Log('The ETag and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
