$Object = Invoke-RestMethod -Uri 'https://updater.prntscr.com/getver/lightshot'

# Version
$this.CurrentState.Version = $Object.update.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.update.installerurl | ConvertTo-Https
}

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
