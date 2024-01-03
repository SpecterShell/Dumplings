$Object1 = Invoke-RestMethod -Uri 'https://desk.likefont.com/client/update' -UserAgent 'likefont/0'

# Version
$this.CurrentState.Version = $Object1.desktop.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.likefont.com/download/windows/LikeFont.exe'
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
