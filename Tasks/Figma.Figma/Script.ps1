$Content = Invoke-RestMethod -Uri 'https://desktop.figma.com/win/RELEASES'

# Version
$Task.CurrentState.Version = [regex]::Match($Content.Split(' ')[1], 'Figma-([\d\.]+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://desktop.figma.com/win/build/Figma-$($Task.CurrentState.Version).exe"
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
