$this.CurrentState = Invoke-WondershareXmlUpgradeApi -ProductId 3313 -Version '1.0.0' -Locale 'en-US'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.wondershare.com/cbs_down/fotophire-maximizer_full3313.exe'
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
