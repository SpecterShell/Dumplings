$Prefix = 'https://x.ai/cli/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}stable" | Read-ResponseContent

# Version
$this.CurrentState.Version = $Object1.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${Prefix}grok-$($this.CurrentState.Version)-windows-x86_64.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "${Prefix}grok-$($this.CurrentState.Version)-windows-aarch64.exe"
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
