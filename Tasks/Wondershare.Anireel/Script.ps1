$this.CurrentState = $LocalStorage.WondershareUpgradeInfo['9589']

$this.CurrentState.Installer[0].AppsAndFeaturesEntries = @(
  [ordered]@{
    DisplayName = "Wondershare Anireel(Build $($this.CurrentState.Version))"
    ProductCode = 'Wondershare Anireel_is1'
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
