$Object = Invoke-RestMethod -Uri "https://is.snssdk.com/service/settings/v3/?device_platform=windows&os_version=10&aid=3704&iid=0&version_code=$($Task.LastState.VersionCode ?? '197888')"

if (-not $Object.data.settings.update_reminder) {
  $Task.Logging("The last version $($Task.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# VersionCode
$Task.CurrentState.VersionCode = $VersionCode = $Object.data.settings.update_reminder.lastest_stable_version

# Version
$Task.CurrentState.Version = @(
  [math]::Floor($VersionCode / 256 / 256).ToString()
  [math]::Floor($VersionCode / 256 % 256).ToString()
  [math]::Floor($VersionCode % 256).ToString()
  $Object.data.settings.update_reminder.lastest_stable_builder_number.ToString()
) -join '.'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.data.settings.update_reminder.lastest_stable_url
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
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
