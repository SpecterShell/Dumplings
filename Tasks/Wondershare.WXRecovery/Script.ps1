$Task.CurrentState = $Temp.WondershareUpgradeInfo['7546']

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/wxrecovery_$($Task.CurrentState.Version)_full7546.exe"
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
