$Object1 = Invoke-WebRequest -Uri 'https://downloads.factory.ai/factory-desktop/LATEST'

# Version
$this.CurrentState.Version = $Object1.Content.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = "https://downloads.factory.ai/factory-desktop/releases/$($this.CurrentState.Version)/win32/x64/Factory-$($this.CurrentState.Version) Setup.exe"
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
