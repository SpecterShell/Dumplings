$this.CurrentState = $Global:DumplingsStorage.WondershareUpgradeInfo['13164']

$this.CurrentState.Installer[0].AppsAndFeaturesEntries = @(
  [ordered]@{
    DisplayName = "万兴录演(Build $($this.CurrentState.Version))"
    ProductCode = '万兴录演_is1'
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
