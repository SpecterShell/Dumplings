$Object1 = Invoke-RestMethod -Uri 'https://update-server.micloud.xiaomi.net/api/v1/releases'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.data.winx64
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'XiaomiCloud-(\d+\.\d+\.\d+)').Groups[1].Value


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
    if (-not $Global:DumplingsStorage.Contains("XiaomiCloudSubmitting-$($this.CurrentState.Version)")) {
      $Global:DumplingsStorage["XiaomiCloudSubmitting-$($this.CurrentState.Version)"] = $ToSubmit = $true
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
