$Task.CurrentState = $Temp.WondershareUpgradeInfo['10819']

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.wondershare.com/cbs_down/wondershareCC_$($Task.CurrentState.Version)_full10819.exe"
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
