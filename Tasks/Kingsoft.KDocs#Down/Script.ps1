$Object1 = (Invoke-RestMethod -Uri 'https://www.kdocs.cn/kdg/api/v1/configure?idList=appOfficial').data.appOfficial | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.kdesktopWinOfficial[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.kdesktopWinOfficial[0].url
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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockKDocs')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("KDocs-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["KDocs-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
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
