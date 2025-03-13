$this.CurrentState = $Global:DumplingsStorage.WondershareUpgradeInfo['619']

# AppsAndFeaturesEntries
$this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
  [ordered]@{
    DisplayName = "Wondershare DVD Creator(Build $($this.CurrentState.Version))"
    ProductCode = 'Wondershare DVD Creator_is1'
  }
)

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
