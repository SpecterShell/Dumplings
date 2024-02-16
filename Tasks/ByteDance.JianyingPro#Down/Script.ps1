$Object1 = Invoke-RestMethod -Uri 'https://lf3-beecdn.bytetos.com/obj/ies-fe-bee/bee_prod/biz_80/bee_prod_80_bee_publish_3563.json'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.windows_download_pkg.channel_default
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+_\d+_\d+_\d+)_jianyingpro').Groups[1].Value.Replace('_', '.')

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match($Object1.windows_version_and_update_date, '(\d{4}/\d{1,2}/\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

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
