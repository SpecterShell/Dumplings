$Object1 = Invoke-RestMethod -Uri 'https://download.eclipse.org/technology/epp/downloads/release/release.xml'

$this.CurrentState.Version = ($Object1.packages.present -split "/")[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://download.eclipse.org/technology/epp/downloads/release/$($this.CurrentState.Version)/R/eclipse-rcp-$($this.CurrentState.Version)-R-win32-x86_64.zip"
}

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://download.eclipse.org/technology/epp/downloads/release/$($this.CurrentState.Version)/R/eclipse-rcp-$($this.CurrentState.Version)-R-win32-aarch64.zip"
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
