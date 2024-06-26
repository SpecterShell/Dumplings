$this.CurrentState = $Global:DumplingsStorage.WondershareUpgradeInfo['7743']

$this.CurrentState.Installer[0].AppsAndFeaturesEntries = @(
  [ordered]@{
    DisplayName = "Wondershare DemoCreator(Build $($this.CurrentState.Version))"
    ProductCode = 'Wondershare DemoCreator_is1'
  }
  [ordered]@{
    DisplayName = "Wondershare DemoCreator Spark(Build $($this.CurrentState.Version))"
    ProductCode = 'Wondershare DemoCreator Spark_is1'
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
