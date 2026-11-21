$Object1 = Invoke-RestMethod -Uri 'https://id.eesti.ee/config.json'

# Version
$this.CurrentState.Version = $Object1.'WIN-LATEST'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.'WIN-DOWNLOAD'
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
