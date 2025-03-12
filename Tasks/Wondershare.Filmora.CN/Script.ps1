$this.CurrentState = $Global:DumplingsStorage.WondershareUpgradeInfo['3223']

$this.CurrentState.Installer[0].AppsAndFeaturesEntries = @(
  [ordered]@{
    DisplayName = "万兴喵影(Build $($this.CurrentState.Version))"
    ProductCode = '万兴喵影_is1'
  }
)

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
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
