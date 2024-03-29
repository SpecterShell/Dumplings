$this.CurrentState = $Global:DumplingsStorage.WondershareUpgradeInfo['9589']

$this.CurrentState.Installer[0].AppsAndFeaturesEntries = @(
  [ordered]@{
    DisplayName = "Wondershare Anireel(Build $($this.CurrentState.Version))"
    ProductCode = 'Wondershare Anireel_is1'
  }
)

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
