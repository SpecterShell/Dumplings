$this.CurrentState = $LocalStorage.WondershareUpgradeInfo['13164']

$this.CurrentState.Installer[0].AppsAndFeaturesEntries = @(
  [ordered]@{
    DisplayName = "万兴录演(Build $($this.CurrentState.Version))"
    ProductCode = '万兴录演_is1'
  }
)

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
