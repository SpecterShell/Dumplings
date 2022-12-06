$Task.CurrentState = $Temp.WondershareUpgradeInfo['13143']

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/pdfreader_$($Task.CurrentState.Version)_full13143.exe"
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/pdfreader_64bit_$($Task.CurrentState.Version)_full13143.exe"
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
