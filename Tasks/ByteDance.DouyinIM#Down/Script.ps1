$Object1 = (Invoke-WebRequest -Uri 'https://www.douyin.com/downloadpage/pc' | ConvertFrom-Html).SelectSingleNode('//*[@id="RENDER_DATA"]').InnerText | ConvertTo-UnescapedUri | ConvertFrom-Json -AsHashtable

# Version
$this.CurrentState.Version = $Object1.app.tccConfig.download_impc_info.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.app.tccConfig.download_impc_info.apk
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.app.tccConfig.download_impc_info.win64Apk
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.app.tccConfig.download_impc_info.time | Get-Date -Format 'yyyy-MM-dd'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $ToSubmit = $false

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsDouyinIM')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $LocalStorage.Contains("DouyinIMSubmitting-$($this.CurrentState.Version)")) {
      $LocalStorage["DouyinIMSubmitting-$($this.CurrentState.Version)"] = $ToSubmit = $true
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
