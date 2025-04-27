$Object1 = Invoke-RestMethod -Uri 'https://autoupdate.mbconnectline.com/api?app=anybusdefendermanager'

# Version
$this.CurrentState.Version = $Object1.newappversion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.dl_path
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
