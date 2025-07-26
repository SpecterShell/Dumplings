$Object1 = Invoke-WebRequest -Uri 'https://release.filestar.com/releases/latest-production.xml' | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.item.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.item.url.Where({ $_.architecture -eq 'win-x86' }, 'First')[0].'#text'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.item.url.Where({ $_.architecture -eq 'win-x64' }, 'First')[0].'#text'
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
