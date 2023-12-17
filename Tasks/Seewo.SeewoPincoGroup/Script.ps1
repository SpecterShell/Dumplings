$Object = $LocalStorage.SeewoApps['SeewoPinco']

# Version
$Task.CurrentState.Version = $Object.softInfos.Where({ $_.softCode -eq 'seewoPincoGroup' }).softVersion

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.softInfos.Where({ $_.softCode -eq 'seewoPincoGroup' }).downloadUrl
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
