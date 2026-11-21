$Object1 = Invoke-RestMethod -Uri 'https://dl.movavi.com/content/wi/resources/release/movavi/pe/pe_win_x64/resources/config.json'

# Version
$this.CurrentState.Version = $Object1.data.Product.version.DefaultValue

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.Installers.Where({ $_.id.DefaultValue -eq 'photoeditor' })[0].url.DefaultValue
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
