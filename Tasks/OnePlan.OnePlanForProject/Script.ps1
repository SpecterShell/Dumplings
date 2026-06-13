$Object1 = Invoke-RestMethod -Uri 'https://templates.oneplan.ai/oneplanconnect/version.json'

# Version
$this.CurrentState.Version = "$($Object1.Version.Major).$($Object1.Version.Minor).$($Object1.Version.Update)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = 'https://templates.oneplan.ai/OnePlanConnect/OnePlanConnect.msi'
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
