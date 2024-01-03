$Object1 = (Invoke-RestMethod -Uri 'https://mastergo.com/api/v1/config').data | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.fontWindow

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://static.mastergo.com/plugins/master-agent/windows/MasterAgentInstall-$($this.CurrentState.Version).exe"
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
