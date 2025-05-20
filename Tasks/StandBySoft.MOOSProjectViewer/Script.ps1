$Object1 = Invoke-RestMethod -Uri 'http://www.moosprojectviewer.com/version.xml'
$Object2 = $Object1.products.product.Where({ $_.name -eq 'MOOS' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.'viewer-link-windows' | ConvertTo-Https
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
