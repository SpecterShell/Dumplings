$Object1 = Invoke-RestMethod -Uri 'https://update-server.micloud.xiaomi.net/api/v1/releases'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.data.winx64
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'XiaomiCloud-(\d+\.\d+\.\d+)').Groups[1].Value


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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockXiaomiCloud')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("XiaomiCloud-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["XiaomiCloud-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
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
