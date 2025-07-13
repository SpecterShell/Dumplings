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
      $Object2 = (Invoke-RestMethod -Uri 'https://pixsoapi.edrawsoft.cn/api/helpcenter/draw/tutorial/list?class_id=6&product=2&platform=51').data[0].content | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h1[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p[1]/span').InnerText | Get-Date -Format 'yyyy-MM-dd'
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
