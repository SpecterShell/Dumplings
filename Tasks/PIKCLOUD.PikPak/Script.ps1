function Get-ReleaseNotes {
  try {
    if ($Global:DumplingsStorage.Contains('PikPak') -and $Global:DumplingsStorage.PikPak.Contains($Version)) {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Global:DumplingsStorage.PikPak.$Version.ReleaseNotesEN
      }
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Global:DumplingsStorage.PikPak.$Version.ReleaseNotesCN
      }
    } else {
      $this.Log("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl1st -Uri 'https://api-drive.mypikpak.com/package/v1/download/official_PikPak.exe?pf=windows'
}

$Object1 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
# ETag
$this.CurrentState.ETag = $Object1.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $Version = $InstallerFile | Read-FileVersionFromExe
  # RealVersion
  $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
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
  # RealVersion
  $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The ETag was not updated
if ($this.CurrentState.ETag -eq $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

$InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
# Version
$this.CurrentState.Version = $Version = $InstallerFile | Read-FileVersionFromExe
# RealVersion
$this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
# InstallerSha256
$this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

# Case 3: The installer file has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}
if ([string]::IsNullOrWhiteSpace($this.CurrentState.RealVersion)) {
  throw 'The current state has an invalid real version'
}

Get-ReleaseNotes

# Case 4: The ETag was updated, but the hash wasn't
if ($this.CurrentState.Installer[0].InstallerUrl -eq $this.LastState.Installer[0].InstallerUrl -and $this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The ETag was changed, but the hash is the same', 'Info')
  $this.Write()
  return
}

switch -Regex ($this.Check()) {
  'Changed|Updated|Rollbacked' {
    # Case 6: The installer URL was updated
    $this.Print()
    $this.Write()
    $this.Message()
  }
  'Updated|Rollbacked' {
    # Case 7: The ETag, hash, and version were updated
    $this.Submit()
  }
  Default {
    # Case 5: Both the ETag and the hash were updated, but the version wasn't
    $this.Log('The ETag and the hash were changed, but the version is the same', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
