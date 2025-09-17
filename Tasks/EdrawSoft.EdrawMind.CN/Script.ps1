$this.CurrentState = $Global:DumplingsStorage.WondershareUpgradeInfo['5375']

if ($this.CurrentState.Installer[0].InstallerUrl.Contains('_gray')) {
  $this.Log("The version $($this.CurrentState.Version) is an A/B test version", 'Error')
  return
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
