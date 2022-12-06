$Object = (Invoke-RestMethod -Uri 'https://mastergo.com/api/v1/config').data | ConvertFrom-Json

# Version
$Task.CurrentState.Version = $Object.fontWindow

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://static.mastergo.com/plugins/master-agent/windows/MasterAgentInstall-$($Task.CurrentState.Version).exe"
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
