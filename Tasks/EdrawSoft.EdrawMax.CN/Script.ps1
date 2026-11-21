$this.CurrentState = $Global:DumplingsStorage.WondershareUpgradeInfo['5374']

if ($this.CurrentState.Installer[0].InstallerUrl.Contains('_gray')) {
  $this.Log("The version $($this.CurrentState.Version) is an A/B test version", 'Error')
  return
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object2 = Invoke-RestMethod -Uri 'https://pixsoapi.edrawsoft.cn/api/helpcenter/draw/tutorial/list?class_id=6&product=2&platform=51'

      if ($Object2.data[0].content.Contains($this.CurrentState.Version)) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($Object2.data[0].content, '(20\d{2}年\d{1,2}月\d{1,2}日)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
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
    $this.Submit()
  }
}
