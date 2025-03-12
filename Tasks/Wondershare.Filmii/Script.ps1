$this.CurrentState = $Global:DumplingsStorage.WondershareUpgradeInfo['7771']

$this.CurrentState.Installer[0].AppsAndFeaturesEntries = @(
  [ordered]@{
    DisplayName = "Wondershare Filmii(Build $($this.CurrentState.Version))"
    ProductCode = 'Wondershare Filmii_is1'
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
