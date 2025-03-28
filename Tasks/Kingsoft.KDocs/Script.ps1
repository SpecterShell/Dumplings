$Object1 = (Invoke-RestMethod -Uri 'https://www.kdocs.cn/kdg/api/v1/configure?idList=kdesktopWinVersion').data.kdesktopWinVersion | ConvertFrom-Json
# $Object1 = (Invoke-RestMethod -Uri 'https://www.kdocs.cn/kd/api/configure/list?idList=kdesktopWinVersion').data.kdesktopWinVersion | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.url.Replace('1002', '1001')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.changes | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
