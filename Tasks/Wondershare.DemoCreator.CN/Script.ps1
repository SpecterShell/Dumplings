$Task.CurrentState = $Temp.WondershareUpgradeInfo['13164']

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/democreator_$($Task.CurrentState.Version)_full13164.exe"
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
