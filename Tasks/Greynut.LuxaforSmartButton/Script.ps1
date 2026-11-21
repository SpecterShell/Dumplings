$Object1 = Invoke-RestMethod -Uri 'https://api.luxafor.com/versioning/api/smartbutton_xk6swgg1qnfhf2l622b5jr28/latest'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://api.luxafor.com/versioning/download/smartbutton_xk6swgg1qnfhf2l622b5jr28/$($this.CurrentState.Version)/LuxaforSmartButton-Installer-$($this.CurrentState.Version).msi"
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
