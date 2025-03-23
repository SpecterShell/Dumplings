function Read-Installer {
  $InstallerFile = Get-TempFile -Uri "$($this.CurrentState.Installer[0].InstallerUrl)?t=$(Get-Date -Format 'yyyyMMdd')"
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

function Get-ReleaseNotes {
  try {
    $ShortVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'
    if ($Global:DumplingsStorage.Contains('Frhelper') -and $Global:DumplingsStorage.Frhelper.Contains($ShortVersion)) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.Frhelper.$ShortVersion.ReleaseTime

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Global:DumplingsStorage.Frhelper.$ShortVersion.ReleaseNotesCN
      }
    } else {
      $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://static.frdic.com/pkg/fhsetup.exe'
}

$Object1 = Invoke-WebRequest -Uri "$($this.CurrentState.Installer[0].InstallerUrl)?t=$(Get-Date -Format 'yyyyMMdd')" -Method Head
$ETag = $Object1.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

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
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
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
    $this.CurrentState.Installer | ForEach-Object -Process { $_.InstallerUrl += "?t=$(Get-Date -Format 'yyyyMMdd')" }
    $this.Message()
    $this.Submit()
  }
  # Case 5: The ETag and the SHA256 have changed, but the version is not
  Default {
    $this.Log('The ETag and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.CurrentState.Installer | ForEach-Object -Process { $_.InstallerUrl += "?t=$(Get-Date -Format 'yyyyMMdd')" }
    $this.Message()
    $this.Submit()
  }
}
