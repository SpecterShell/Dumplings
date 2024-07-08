function Get-ReleaseNotes {
  try {
    if ($Global:DumplingsStorage.Contains('AdobeAIR') -and $Global:DumplingsStorage.AdobeAIR.Contains($Version)) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.AdobeAIR.$Version.ReleaseTime | Get-Date -AsUTC
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Global:DumplingsStorage.AdobeAIR.$Version.ReleaseNotes
      }
    } else {
      $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://airsdk.harman.com/assets/downloads/AdobeAIR.exe'
}

$Object1 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
# Last Modified
$this.CurrentState.LastModified = $Object1.Headers.'Last-Modified'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $Version = $InstallerFile | Read-FileVersionFromExe
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is newly created
if ($this.Status.Contains('New')) {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $Version = $InstallerFile | Read-FileVersionFromExe
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The Last Modified was not updated
if ($this.CurrentState.LastModified -eq $this.LastState.LastModified) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

$InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
# Version
$this.CurrentState.Version = $Version = $InstallerFile | Read-FileVersionFromExe
# InstallerSha256
$this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

# Case 3: The installer file has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

# Case 4: The Last Modified was updated, but the hash wasn't
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The Last Modified was changed, but the hash is the same', 'Info')
  $this.Write()
  return
}

switch -Regex ($this.Check()) {
  'Updated|Rollbacked' {
    # Case 6: The Last Modified, hash, and version were updated
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
    return
  }
  Default {
    # Case 5: Both the Last Modified and the hash were updated, but the version wasn't
    $this.Log('The Last Modified and the hash were changed, but the version is the same', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
    return
  }
}
