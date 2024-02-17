$this.CurrentState = Invoke-WondershareXmlDownloadApi -ProductId 7920 -Wae '3.0.1'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.wondershare.com/cbs_down/inclowdz_full7920.exe'
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
