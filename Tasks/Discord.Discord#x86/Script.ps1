# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x86'
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '/(\d+\.\d+\.\d+(?:\.\d+)*)/').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Updated' {
    $this.Print()
    $this.Write()
  }
  'Updated' {
    $this.Message()
  }
}
