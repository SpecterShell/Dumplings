$this.CurrentState = Invoke-WondershareXmlUpgradeApi -ProductId 4583 -Version '1.0.0.0' -Locale 'en-US'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl           = 'https://download.wondershare.com/cbs_down/fotophire-slideshow-maker_full4583.exe'
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName = "Wondershare Fotophire Slideshow Maker(Build $($this.CurrentState.Version))"
      ProductCode = 'Wondershare Fotophire Slideshow Maker_is1'
    }
  )
}

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
