$Object1 = Invoke-RestMethod -Uri 'https://desktop.figma.com/win/RELEASES'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Split(' ')[1], '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://desktop.figma.com/win/build/Figma-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://desktop.figma.com/win-arm/build/Figma-$($this.CurrentState.Version).exe"
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
