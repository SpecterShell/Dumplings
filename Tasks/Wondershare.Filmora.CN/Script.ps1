$Task.CurrentState = $Temp.WondershareUpgradeInfo['3223']

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/filmora_$($Task.CurrentState.Version)_full3223.exe"
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
