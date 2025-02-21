$Object1 = Invoke-RestMethod -Uri 'https://cdn.pdffiller.com/desktop-win/pdfFiller-appcast.xml'

# Version
$this.CurrentState.Version = $Object1.item.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.item.url
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
