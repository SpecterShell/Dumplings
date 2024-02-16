$Object1 = Invoke-RestMethod -Uri "https://is.snssdk.com/service/settings/v3/?device_platform=windows&os_version=10&aid=3704&iid=0&version_code=$($this.LastState.VersionCode ?? '197888')"

if (-not $Object1.data.settings.update_reminder) {
  $this.Log("The last version $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# VersionCode
$this.CurrentState.VersionCode = $VersionCode = $Object1.data.settings.update_reminder.lastest_stable_version

# Version
$this.CurrentState.Version = @(
  [math]::Floor($VersionCode / 256 / 256).ToString()
  [math]::Floor($VersionCode / 256 % 256).ToString()
  [math]::Floor($VersionCode % 256).ToString()
  $Object1.data.settings.update_reminder.lastest_stable_builder_number.ToString()
) -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.settings.update_reminder.lastest_stable_url
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.settings.update_reminder.lastest_stable_update_content | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $ToSubmit = $false

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsJianyingPro')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $LocalStorage.Contains("JianyingProSubmitting-$($this.CurrentState.Version)")) {
      $LocalStorage["JianyingProSubmitting-$($this.CurrentState.Version)"] = $ToSubmit = $true
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
