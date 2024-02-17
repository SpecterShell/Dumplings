$Object1 = Invoke-RestMethod -Uri 'https://updater.prntscr.com/getver/lightshot'

# Version
$this.CurrentState.Version = $Object1.update.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.update.installerurl | ConvertTo-Https
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
