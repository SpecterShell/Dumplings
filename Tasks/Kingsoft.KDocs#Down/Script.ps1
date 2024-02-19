$Response = Invoke-RestMethod -Uri 'https://www.kdocs.cn/kd/api/configure/list?idList=kdesktopVersion,autoDownload'
$Object1 = $Response.data.kdesktopVersion | ConvertFrom-Json
$Object2 = $Response.data.autoDownload | ConvertFrom-Json

# Version
$this.CurrentState.Version = [regex]::Match($Object1.win, 'v([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.kdesktopWin.1001
}

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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsKDocs')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $LocalStorage.Contains("KDocsSubmitting-$($this.CurrentState.Version)")) {
      $LocalStorage["KDocsSubmitting-$($this.CurrentState.Version)"] = $ToSubmit = $true
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
