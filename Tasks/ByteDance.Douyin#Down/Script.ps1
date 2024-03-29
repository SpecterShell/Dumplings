$Object1 = (Invoke-WebRequest -Uri 'https://www.douyin.com/downloadpage/pc' | ConvertFrom-Html).SelectSingleNode('//*[@id="RENDER_DATA"]').InnerText | ConvertTo-UnescapedUri | ConvertFrom-Json -AsHashtable

# Version
$this.CurrentState.Version = $Object1.app.tccConfig.download_info.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.app.tccConfig.download_info.apk.Replace('lf3-cdn-tos.bytegoofy.com', 'www.douyin.com/download/pc')
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.app.tccConfig.download_info.time | Get-Date -Format 'yyyy-MM-dd'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
