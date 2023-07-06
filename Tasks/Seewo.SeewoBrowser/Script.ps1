$Object = $Temp.SeewoApps['seewobrowser']

# Version
$Task.CurrentState.Version = [regex]::Matches($Object.softInfos[0].softVersion, '([\d\.]+)').Groups[-1].Value

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
