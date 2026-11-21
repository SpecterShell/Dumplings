$Object1 = Invoke-RestMethod -Uri 'https://storage.googleapis.com/nextdns_windows/info.json'

# Version
$this.CurrentState.Version = $Object1.stable.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.stable.url
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
