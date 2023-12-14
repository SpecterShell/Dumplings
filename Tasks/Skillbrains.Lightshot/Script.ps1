$Object = Invoke-RestMethod -Uri 'https://updater.prntscr.com/getver/lightshot'

# Version
$Task.CurrentState.Version = $Object.update.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.update.installerurl | ConvertTo-Https
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
