$this.CurrentState = $Global:LocalStorage.WondershareUpgradeInfo['9589']

$this.CurrentState.Installer[0].AppsAndFeaturesEntries = @(
  [ordered]@{
    DisplayName = "Wondershare Anireel(Build $($this.CurrentState.Version))"
    ProductCode = 'Wondershare Anireel_is1'
  }
)

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
