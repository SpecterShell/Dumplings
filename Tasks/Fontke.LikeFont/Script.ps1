$Object = Invoke-RestMethod -Uri 'https://desk.likefont.com/client/update' -UserAgent 'likefont/0'

# Version
$Task.CurrentState.Version = $Object.desktop.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.likefont.com/download/windows/LikeFont.exe'
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
