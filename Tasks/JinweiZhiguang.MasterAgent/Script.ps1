$Object = (Invoke-RestMethod -Uri 'https://mastergo.com/api/v1/config').data | ConvertFrom-Json

# Version
$Task.CurrentState.Version = $Object.fontWindow

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://static.mastergo.com/plugins/master-agent/windows/MasterAgentInstall-$($Task.CurrentState.Version).exe"
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
