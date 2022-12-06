$Task.CurrentState = $Temp.WondershareUpgradeInfo['5239']

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://download.wondershare.com/cbs_down/pdfelement-pro_$($Task.CurrentState.Version)_full5239.exe"
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://download.wondershare.com/cbs_down/pdfelement-pro_64bit_$($Task.CurrentState.Version)_full5239.exe"
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
