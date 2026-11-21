$regifyClient = $Global:DumplingsStorage.RegifyClients['regify_client']

# Version
$this.CurrentState.Version = $regifyClient.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $regifyClient.InstallerUrl
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
