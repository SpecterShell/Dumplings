$Object1 = Invoke-RestMethod -Uri "https://www.datensen.com/api/GalaxyModeler/v3/$($this.Status.Contains('New') ? '9.1.0' : $this.LastState.Version)/t/trial/d/0"

# Version
$this.CurrentState.Version = $Object1.data[1]

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://www.datensen.com/downloads/Galaxy Modeler-$($this.CurrentState.Version)-x64.exe"
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
