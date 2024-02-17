$this.CurrentState = $LocalStorage.WondershareUpgradeInfo['7743']

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

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
