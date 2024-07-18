$Object1 = Invoke-RestMethod -Uri 'https://cdn07.boxcdn.net/Autoupdate5.json'

# Version
$this.CurrentState.Version = $Object1.win.enterprise.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.win.enterprise.'download-url'
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
