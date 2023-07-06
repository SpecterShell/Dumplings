$Object = $Temp.SeewoApps['SeewoPinco']

# Version
$Task.CurrentState.Version = $Object.softInfos.Where({ $_.softCode -eq 'seewoPincoTeacher' }).softVersion

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.softInfos.Where({ $_.softCode -eq 'seewoPincoTeacher' }).downloadUrl
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
