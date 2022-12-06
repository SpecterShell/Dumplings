$Object = Invoke-RestMethod -Uri 'https://updater.prntscr.com/getver/lightshot'

# Version
$Task.CurrentState.Version = $Object.update.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.update.installerurl | ConvertTo-Https
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
