$this.CurrentState.Version = $Global:DumplingsStorage.EclipseVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/$($this.CurrentState.Version)/R/eclipse-php-$($this.CurrentState.Version)-R-win32-x86_64.zip&r=1"
}

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/$($this.CurrentState.Version)/R/eclipse-php-$($this.CurrentState.Version)-R-win32-aarch64.zip&r=1"
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
