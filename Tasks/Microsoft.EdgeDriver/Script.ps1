$Object1 = (Invoke-WebRequest -Uri 'https://msedgedriver.microsoft.com/LATEST_STABLE' | Read-ResponseContent).Trim()

# Version
$this.CurrentState.Version = $Object1

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://msedgedriver.microsoft.com/$($this.CurrentState.Version)/edgedriver_win32.zip"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://msedgedriver.microsoft.com/$($this.CurrentState.Version)/edgedriver_win64.zip"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://msedgedriver.microsoft.com/$($this.CurrentState.Version)/edgedriver_arm64.zip"
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
