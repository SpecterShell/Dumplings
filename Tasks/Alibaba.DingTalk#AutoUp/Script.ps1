$Object1 = Invoke-WebRequest -Uri 'https://im.dingtalk.com/manifest/new/release_windows_vista_later_all.json' | Read-ResponseContent | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.win.package.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.win.install.url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match($Object1.win.install.description[0], '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.win.install.multi_lang_description.en_US | Select-Object -Skip 1 | Format-Text
}
# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.win.install.description | Select-Object -Skip 1 | Format-Text
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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsDingTalk')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $LocalStorage.Contains("DingTalkSubmitting-$($this.CurrentState.Version)")) {
      $LocalStorage["DingTalkSubmitting-$($this.CurrentState.Version)"] = $ToSubmit = $true
    }
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()

    if ($ToSubmit) {
      $this.Submit()
    } else {
      $this.Logging('Another task is submitting manifests for this package', 'Warning')
    }
  }
}
