$Prefix = 'https://static.ampcode.com/cli/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}cli-version.txt"

# Version
$this.CurrentState.Version = $Object1.Content.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${Prefix}$($this.CurrentState.Version)/amp-windows-x64-baseline.exe"
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
