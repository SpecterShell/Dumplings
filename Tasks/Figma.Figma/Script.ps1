$Object1 = Invoke-RestMethod -Uri 'https://desktop.figma.com/win/RELEASES'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Split(' ')[1], '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://desktop.figma.com/win/build/Figma-$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
