$Object = Invoke-RestMethod -Uri 'https://desk.likefont.com/client/update' -UserAgent 'likefont/0'

# Version
$Task.CurrentState.Version = $Object.desktop.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.likefont.com/download/windows/LikeFont.exe'
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
