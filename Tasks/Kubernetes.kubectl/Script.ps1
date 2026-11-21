$Object1 = Invoke-WebRequest -Uri 'https://dl.k8s.io/release/stable.txt'

# Version
$this.CurrentState.Version = $Object1.Content.Trim() -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://dl.k8s.io/release/v$($this.CurrentState.Version)/bin/windows/386/kubectl.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://dl.k8s.io/release/v$($this.CurrentState.Version)/bin/windows/amd64/kubectl.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://dl.k8s.io/release/v$($this.CurrentState.Version)/bin/windows/arm64/kubectl.exe"
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
