$Object1 = Invoke-RestMethod -Uri 'https://api.luxafor.com/versioning/api/luxafor_blz159is6sp00pugtpqi0fvq/latest'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://api.luxafor.com/versioning/download/luxafor_blz159is6sp00pugtpqi0fvq/$($this.CurrentState.Version)/LuxaforApp-Installer-$($this.CurrentState.Version).msi"
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
