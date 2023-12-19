$Content = Invoke-RestMethod -Uri 'https://desktop.figma.com/win/RELEASES'

# Version
$this.CurrentState.Version = [regex]::Match($Content.Split(' ')[1], 'Figma-([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://desktop.figma.com/win/build/Figma-$($this.CurrentState.Version).exe"
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
