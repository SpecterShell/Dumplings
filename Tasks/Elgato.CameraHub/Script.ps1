$Object1 = Invoke-RestMethod -Uri 'https://gc-updates.elgato.com/windows/echw-update/final/app-version-check.json.php' -UserAgent "CameraHub/$($this.Status.Contains('New') ? '2.0.0.5721' : $this.LastState.Version) - Windows/10.0.22000 cpu/x86_64 locale/en-US"

# Version
$this.CurrentState.Version = $Object1.Manual.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Manual.fileURL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $Object1.Manual.ReleaseNotes.en
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectSingleNode('/html/body') | Get-TextContent | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $ToSubmit = $false

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockCameraHub')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("CameraHub-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["CameraHub-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
    }
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()

    if ($ToSubmit) {
      $this.Submit()
    } else {
      $this.Log('Another task is submitting manifests for this package', 'Warning')
    }
  }
}
