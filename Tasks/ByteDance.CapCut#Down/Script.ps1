$Object1 = Invoke-RestMethod -Uri 'https://editor-api-sg.capcut.com/service/settings/v3/?device_platform=windows&aid=359289&from_aid=359289&from_version=0.0.0'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.data.settings.installer_downloader_config.url
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+_\d+_\d+_\d+)').Groups[1].Value.Replace('_', '.')

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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockCapCut')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("CapCut-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["CapCut-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
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
