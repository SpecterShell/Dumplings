$Object1 = (Invoke-WebRequest -Uri 'https://editor-api-sg.capcut.com/service/settings/v3/?device_platform=windows&os_version=10&aid=359289&iid=0&version_code=66304').Content | ConvertFrom-Json -AsHashtable

if (-not $Object1.data.settings.Contains('update_reminder')) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# VersionCode
$this.CurrentState.VersionCode = $VersionCodeBase = $Object1.data.settings.update_reminder.lastest_stable_version

# Version
$this.CurrentState.Version = @(
  [math]::Floor($VersionCodeBase / 256 / 256).ToString()
  [math]::Floor($VersionCodeBase / 256 % 256).ToString()
  [math]::Floor($VersionCodeBase % 256).ToString()
  $Object1.data.settings.update_reminder.lastest_stable_builder_number.ToString()
) -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.settings.update_reminder.lastest_stable_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.settings.update_reminder.lastest_stable_update_content | Format-Text
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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockCapCut')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("CapCut-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["CapCut-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
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
