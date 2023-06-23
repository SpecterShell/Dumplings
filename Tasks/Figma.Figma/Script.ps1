$Content = Invoke-RestMethod -Uri 'https://desktop.figma.com/win/RELEASES'

# Version
$Task.CurrentState.Version = [regex]::Match($Content.Split(' ')[1], 'Figma-([\d\.]+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://desktop.figma.com/win/build/Figma-$($Task.CurrentState.Version).exe"
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
