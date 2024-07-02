$Object1 = Invoke-RestMethod -Uri 'https://remote-config.gog.com/components/webinstaller?component_version=2.0.0'

# Version
$this.CurrentState.Version = $Object1.content.windows.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.content.windows.downloadLink
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
