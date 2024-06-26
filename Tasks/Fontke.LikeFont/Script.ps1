$Object1 = Invoke-RestMethod -Uri 'https://desk.likefont.com/client/update' -UserAgent 'likefont/0'

# Version
$this.CurrentState.Version = $Object1.desktop.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.likefont.com/download/windows/LikeFont.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
