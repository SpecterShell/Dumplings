$Object = Invoke-RestMethod -Uri "https://editor-api-sg.capcut.com/service/settings/v3/?device_platform=windows&os_version=10&aid=359289&iid=0&version_code=$($Task.LastState.VersionCode ?? '66304')"

if (-not $Object.data.settings.update_reminder) {
  Write-Host -Object "Task $($Task.Name): The last version $($Task.LastState.Version) is the latest, skip checking" -ForegroundColor Yellow
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

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
}
