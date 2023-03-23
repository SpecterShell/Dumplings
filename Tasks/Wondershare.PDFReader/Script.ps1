$Task.CurrentState = $Temp.WondershareUpgradeInfo['13142']

# Installer
$Task.CurrentState.Installer.Clear()
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://download.wondershare.com/cbs_down/pdfreader_$($Task.CurrentState.Version)_full13142.exe"
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://download.wondershare.com/cbs_down/pdfreader_64bit_$($Task.CurrentState.Version)_full13142.exe"
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
