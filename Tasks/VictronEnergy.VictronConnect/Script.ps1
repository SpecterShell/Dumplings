$Object1 = Invoke-WebRequest -Uri 'https://updates.victronenergy.com/feeds/VictronConnect/windows/w10/version.txt'

# Version
$this.CurrentState.Version = $Object1.Content.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://updates.victronenergy.com/feeds/VictronConnect/windows/w10/VictronConnectInstaller.exe'
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
