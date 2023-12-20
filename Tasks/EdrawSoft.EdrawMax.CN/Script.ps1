$this.CurrentState = $LocalStorage.WondershareUpgradeInfo['5374']

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    $Object2 = (Invoke-RestMethod -Uri 'https://pixsoapi.edrawsoft.cn/api/helpcenter/draw/tutorial/list?class_id=6&product=2&platform=2').data[0].content | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h1[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::h6[1]/span').InnerText | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $this.Logging("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
