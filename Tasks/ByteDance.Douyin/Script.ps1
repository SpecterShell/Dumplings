$Object1 = Invoke-WebRequest -Uri 'https://api.toutiaoapi.com/service/settings/v3/' -Body @{
  aid             = '430651'
  device_platform = 'pc'
  from_aid        = '6383'
  from_channel    = ''
  from_version    = $this.Status.Contains('New') ? '5.2.1' : $this.LastState.Version
} | Read-ResponseContent | ConvertFrom-Json -AsHashtable

if (-not $Object1.data.settings.Contains('douyin_pc_update')) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.data.settings.douyin_pc_update.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.data.settings.douyin_pc_update.url.Replace('mix', 'ia32').Replace('x64', 'ia32')
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.data.settings.douyin_pc_update.url.Replace('mix', 'x64').Replace('ia32', 'x64')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.settings_time | ConvertFrom-UnixTimeSeconds

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.settings.douyin_pc_update.notes | Format-Text
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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsDouyin')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("DouyinSubmitting-$($this.CurrentState.Version)")) {
      $Global:DumplingsStorage["DouyinSubmitting-$($this.CurrentState.Version)"] = $ToSubmit = $true
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
