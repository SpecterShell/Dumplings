$Object = $Temp.SeewoApps['SeewoIotManageWebApp']

# Version
$Task.CurrentState.Version = $Object.softInfos[0].softVersion

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.softInfos[0].downloadUrl
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
