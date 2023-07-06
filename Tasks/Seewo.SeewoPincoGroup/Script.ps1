$Object = $Temp.SeewoApps['SeewoPinco']

# Version
$Task.CurrentState.Version = $Object.softInfos.Where({ $_.softCode -eq 'seewoPincoGroup' }).softVersion

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.softInfos.Where({ $_.softCode -eq 'seewoPincoGroup' }).downloadUrl
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
