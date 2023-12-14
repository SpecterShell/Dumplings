$Object = Invoke-RestMethod -Uri 'https://editor-api-sg.capcut.com/service/settings/v3/?device_platform=windows&aid=359289&from_aid=359289&from_version=0.0.0'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object.data.settings.installer_downloader_config.url
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+_\d+_\d+_\d+)_capcutpc').Groups[1].Value.Replace('_', '.')

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
