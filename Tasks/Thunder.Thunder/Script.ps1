$Object1 = Invoke-RestMethod -Uri 'https://client-version.office.k8s.xunlei.cn/ci/v1/public/versionManage/versions/latest?clientId=XW-G4v1H72tgfJym'

# Version
$this.CurrentState.Version = $Object1.data.versionName

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.officialUrlThunderPcOffline
}

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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockThunder')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("Thunder-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["Thunder-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
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
