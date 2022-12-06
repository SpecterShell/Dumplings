$Task.CurrentState = $Temp.WondershareUpgradeInfo['9629']

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.wondershare.com/cbs_down/uniconverter13_$($Task.CurrentState.Version)_full9629.exe"
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
