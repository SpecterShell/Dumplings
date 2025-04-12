function Read-Installer {
  $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri "$($this.CurrentState.Installer[0].InstallerUrl)?t=$(Get-Date -Format 'yyyyMMdd')"
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-FileVersionFromExe
  # RealVersion
  $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
}

function Get-ReleaseNotes {
  try {
    if ($Global:DumplingsStorage.Contains('PikPak') -and $Global:DumplingsStorage.PikPak.Contains($this.CurrentState.Version)) {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Global:DumplingsStorage.PikPak[$this.CurrentState.Version].ReleaseNotes
      }
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Global:DumplingsStorage.PikPak[$this.CurrentState.Version].ReleaseNotesCN
      }
    } else {
      $this.Log("No ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl1st -Uri 'https://api-drive.mypikpak.com/package/v1/download/official_PikPak.exe?pf=windows' -Method GET
}

$Object1 = Invoke-WebRequest -Uri "$($this.CurrentState.Installer[0].InstallerUrl)?t=$(Get-Date -Format 'yyyyMMdd')" -Method Head
# Hash
$this.CurrentState.Hash = $Object1.Headers.'Content-MD5'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  $this.CurrentState.Installer | ForEach-Object -Process { $_.InstallerUrl += "?t=$(Get-Date -Format 'yyyyMMdd')" }
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
if ([string]::IsNullOrWhiteSpace($this.CurrentState.RealVersion)) {
  throw 'The current state has an invalid real version'
}

Get-ReleaseNotes

switch -Regex ($this.Check()) {
  # Case 5: The installer URL has changed
  'Changed|Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.CurrentState.Installer | ForEach-Object -Process { $_.InstallerUrl += "?t=$(Get-Date -Format 'yyyyMMdd')" }
    $this.Message()
  }
  # Case 6: The hash and the version have changed
  'Updated|Rollbacked' {
    $this.Submit()
  }
  # Case 4: The hash has changed, but the version is not
  Default {
    $this.Log('The hash has changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.CurrentState.Installer | ForEach-Object -Process { $_.InstallerUrl += "?t=$(Get-Date -Format 'yyyyMMdd')" }
    $this.Message()
    $this.Submit()
  }
}
