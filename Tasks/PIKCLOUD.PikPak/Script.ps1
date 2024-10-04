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

$Object1 = Invoke-WebRequest -Uri "$($this.CurrentState.Installer[0].InstallerUrl)?t=$(Get-Date -Format 'yyyyMMdd')" -Method Head
# MD5
$this.CurrentState.MD5 = $Object1.Headers.'Content-MD5'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  $InstallerFile = Get-TempFile -Uri "$($this.CurrentState.Installer[0].InstallerUrl)?t=$(Get-Date -Format 'yyyyMMdd')"
  # Version
  $this.CurrentState.Version = $Version = $InstallerFile | Read-FileVersionFromExe
  # RealVersion
  $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  $this.CurrentState.Installer | ForEach-Object -Process { $_.InstallerUrl += "?t=$(Get-Date -Format 'yyyyMMdd')" }
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is newly created
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  $InstallerFile = Get-TempFile -Uri "$($this.CurrentState.Installer[0].InstallerUrl)?t=$(Get-Date -Format 'yyyyMMdd')"
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

# Case 2: The MD5 was not updated
if ($this.CurrentState.MD5 -eq $this.LastState.MD5) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

$InstallerFile = Get-TempFile -Uri "$($this.CurrentState.Installer[0].InstallerUrl)?t=$(Get-Date -Format 'yyyyMMdd')"
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

switch -Regex ($this.Check()) {
  # Case 5: The installer URL was updated
  'Changed|Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.CurrentState.Installer | ForEach-Object -Process { $_.InstallerUrl += "?t=$(Get-Date -Format 'yyyyMMdd')" }
    $this.Message()
  }
  # Case 6: The MD5 and the version were updated
  'Updated|Rollbacked' {
    $this.Submit()
  }
  # Case 4: The MD5 was updated, but the version wasn't
  Default {
    $this.Log('The MD5 was changed, but the version is the same', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.CurrentState.Installer | ForEach-Object -Process { $_.InstallerUrl += "?t=$(Get-Date -Format 'yyyyMMdd')" }
    $this.Message()
    $this.Submit()
  }
}
