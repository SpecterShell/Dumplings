# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://discord.com/api/downloads/distributions/app/installers/latest?channel=development&platform=win&arch=x64'
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '/(\d+\.\d+\.\d+(?:\.\d+)*)/').Groups[1].Value

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
