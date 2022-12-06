$Task.CurrentState = $Temp.WondershareUpgradeInfo['5370']

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.edrawsoft.com/cbs_down/edrawmind_$($Task.CurrentState.version)_full5370.exe"
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
