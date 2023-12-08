$Object = Invoke-RestMethod -Uri 'https://editor-api-sg.capcut.com/service/settings/v3/?device_platform=windows&aid=359289&from_aid=359289&from_version=0.0.0'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object.data.settings.installer_downloader_config.url
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+_\d+_\d+_\d+)_capcutpc').Groups[1].Value.Replace('_', '.')

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
