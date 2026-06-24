$Prefix = 'https://download.dataservices.theice.com/products/iceexcel/install/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}info"

# Version
$this.CurrentState.Version = $Object1.VERSION

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.INSTALLER
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
