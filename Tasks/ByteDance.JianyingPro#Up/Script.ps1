$Object = Invoke-RestMethod -Uri "https://is.snssdk.com/service/settings/v3/?device_platform=windows&os_version=10&aid=3704&iid=0&version_code=$($Task.LastState.VersionCode ?? '197888')"

# VersionCode
$Task.CurrentState.VersionCode = $Object.data.settings.update_reminder.lastest_stable_version

# Version
$VersionCodeBase = $Task.CurrentState.VersionCode - 188928
$Task.CurrentState.Version = @(
  [math]::Floor($VersionCodeBase / 256 / 10).ToString()
  [math]::Floor($VersionCodeBase / 256 % 10).ToString()
  [math]::Floor($VersionCodeBase % 256).ToString()
  $Object.data.settings.update_reminder.lastest_stable_builder_number.ToString()
) -join '.'

# Installer
$InstallerUrl = $Object.data.settings.update_reminder.lastest_stable_url
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
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
