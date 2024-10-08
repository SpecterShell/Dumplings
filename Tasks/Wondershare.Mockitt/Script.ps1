$Object1 = Invoke-RestMethod -Uri 'https://mockitt.wondershare.com/api/v2/client/desktop/check_update.json' -Body @{
  region   = 'US'
  version  = $this.LastState.Contains('Version') ? $this.LastState.Version : '6.0.0'
  platform = 'win32'
  arch     = 'x64'
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.wondershare.com/cbs_down/mockitt_full8040.exe'
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
