$this.CurrentState = $Global:DumplingsStorage.WondershareUpgradeInfo['4583']

# AppsAndFeaturesEntries
$this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
  [ordered]@{
    DisplayName = "Wondershare Fotophire Slideshow Maker(Build $($this.CurrentState.Version))"
    ProductCode = 'Wondershare Fotophire Slideshow Maker_is1'
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
