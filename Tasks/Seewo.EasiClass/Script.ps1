$Object = $Temp.SeewoApps['EasiClassPC']

# Version
$Task.CurrentState.Version = $Object.softInfos[0].softVersion

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.softInfos[0].downloadUrl
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
