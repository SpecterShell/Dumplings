$Object = Invoke-RestMethod -Uri "https://editor-api-sg.capcut.com/service/settings/v3/?device_platform=windows&os_version=10&aid=359289&iid=0&version_code=$($Task.LastState.VersionCode ?? '66304')"

if (-not $Object.data.settings.update_reminder) {
  $Task.Logging("The last version $($Task.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# VersionCode
$Task.CurrentState.VersionCode = $Object.data.settings.update_reminder.lastest_stable_version

# Version
$VersionCodeBase = $Task.CurrentState.VersionCode
$Task.CurrentState.Version = @(
  [math]::Floor($VersionCodeBase / 256 / 256).ToString()
  [math]::Floor($VersionCodeBase / 256 % 256).ToString()
  [math]::Floor($VersionCodeBase % 256).ToString()
  $Object.data.settings.update_reminder.lastest_stable_builder_number.ToString()
) -join '.'

# Installer
$InstallerUrl = $Object.data.settings.update_reminder.lastest_stable_url
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.settings.update_reminder.lastest_stable_update_content | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
}
