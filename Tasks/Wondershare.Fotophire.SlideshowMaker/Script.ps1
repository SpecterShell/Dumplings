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
