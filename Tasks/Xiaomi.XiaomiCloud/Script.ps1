$Object1 = Invoke-RestMethod -Uri 'https://update-server.micloud.xiaomi.net/api/v1/releases'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.data.winx64
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'XiaomiCloud-(\d+\.\d+\.\d+)').Groups[1].Value


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
      $this.Log('Another task is submitting manifests for this package', 'Warning')
    }
  }
}
