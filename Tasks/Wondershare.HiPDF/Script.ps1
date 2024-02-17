$this.CurrentState = Invoke-WondershareXmlUpgradeApi -ProductId 7411 -Version '1.0.0.0' -Locale 'en-US'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.wondershare.com/cbs_down/hipdf-desktop_full7411.exe'
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
