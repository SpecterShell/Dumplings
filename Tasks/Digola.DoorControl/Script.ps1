$Object1 = Invoke-WebRequest -Uri 'https://digola.com/doorcontrol.html'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'Version:(?:\s|&nbsp;)*(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://digola.com/setupdoorcontrol.exe'
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
