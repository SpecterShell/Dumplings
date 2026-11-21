$Object1 = Invoke-RestMethod -Uri 'http://mtupdates.altervista.org/download/MT.currver' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.Info.AppCurrentVersionText

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'inno'
  InstallerUrl        = 'https://www.havysoft.cl/download/MT-Install.zip'
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
