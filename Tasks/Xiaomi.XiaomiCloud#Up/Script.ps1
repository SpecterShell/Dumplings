$Prefix = 'https://cdn.cnbj1.fds.api.mi-img.com/archive/update-server/public/win32/x64/'

$this.CurrentState = Invoke-RestMethod -Uri "https://update-server.micloud.xiaomi.net/api/v1/latest.yml?channel=public&platform=win32&arch=x64&machine_id=$((New-Guid).Guid)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $ToSubmit = $false

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsXiaomiCloud')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $LocalStorage.Contains("XiaomiCloudSubmitting-$($this.CurrentState.Version)")) {
      $LocalStorage["XiaomiCloudSubmitting-$($this.CurrentState.Version)"] = $ToSubmit = $true
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
