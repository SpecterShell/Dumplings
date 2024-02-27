$Prefix = 'https://cdn.cnbj1.fds.api.mi-img.com/archive/update-server/public/win32/x64/'

$this.CurrentState = Invoke-RestMethod -Uri "https://update-server.micloud.xiaomi.net/api/v1/latest.yml?channel=public&platform=win32&arch=x64&machine_id=$((New-Guid).Guid)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $ToSubmit = $false

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsXiaomiCloud')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:LocalStorage.Contains("XiaomiCloudSubmitting-$($this.CurrentState.Version)")) {
      $Global:LocalStorage["XiaomiCloudSubmitting-$($this.CurrentState.Version)"] = $ToSubmit = $true
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
