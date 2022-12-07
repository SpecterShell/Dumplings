$Object = Invoke-RestMethod -Uri 'https://www.larksuite.com/api/downloads'

# Version
$Task.CurrentState.Version = [regex]::Match($Object.versions.Windows.version_number, 'V([\d\.]+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.versions.Windows.download_link
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.versions.Windows.release_time | ConvertFrom-UnixTimeSeconds

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
