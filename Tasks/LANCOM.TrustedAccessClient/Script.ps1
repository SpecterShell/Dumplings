function Read-Installer {
  foreach ($Installer in $this.CurrentState.Installer) {
    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'LC-Advanced-VPN-Client-Win-x86-64.msi'
    # Version
    $this.CurrentState.Version = $InstallerFile2 | Read-ProductVersionFromMsi
    # ProductCode
    $Installer['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $Installer['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
  }
}

function Get-ReleaseNotes {
  try {
    # ReleaseNotesUrl (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotesUrl'
      Value  = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('RN') -and $_.href.Contains('Windows') } catch {} }, 'First')[0].href
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$Prefix = 'https://www.lancom-systems.com/products/remote-mobile-access/lancom-trusted-access-client'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('x86-64') } catch {} }, 'First')[0].href
}

$Object2 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
# Last Modified
$this.CurrentState.LastModified = $Object2.Headers.'Last-Modified'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

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

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The Last Modified is unchanged
if ([datetime]$this.CurrentState.LastModified -eq [datetime]$this.LastState.LastModified) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
} elseif ([datetime]$this.CurrentState.LastModified -lt [datetime]$this.LastState.LastModified) {
  $this.Log("The last modified datetime from the current state `"$($this.CurrentState.LastModified)`" is older than the one from the last state `"$($this.LastState.LastModified)`"", 'Warning')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

# Case 4: The Last Modified has updated, but the SHA256 is not
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The Last Modified has changed, but the SHA256 is not', 'Info')

  $this.Write()
  return
}

switch -Regex ($this.Check()) {
  # Case 6: The Last Modified, the SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 5: The Last Modified and the SHA256 have changed, but the version is not
  default {
    $this.Log('The Last Modified and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
