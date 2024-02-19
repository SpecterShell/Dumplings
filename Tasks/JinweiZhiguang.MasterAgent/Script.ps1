$Object1 = (Invoke-RestMethod -Uri 'https://mastergo.com/api/v1/config').data | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.fontWindow

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://static.mastergo.com/plugins/master-agent/windows/MasterAgentInstall-$($this.CurrentState.Version).exe"
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
