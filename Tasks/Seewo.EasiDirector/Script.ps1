$Object = $Temp.SeewoApps['EasiDirector']

# Version
$Task.CurrentState.Version = $Object.softInfos[0].softVersion

# RealVersion
$Task.CurrentState.RealVersion = '1.0.0.0'

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
