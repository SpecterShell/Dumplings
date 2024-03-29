$Object1 = Invoke-RestMethod -Uri 'https://updater.prntscr.com/getver/lightshot'

# Version
$this.CurrentState.Version = $Object1.update.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.update.installerurl | ConvertTo-Https
}

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
