$Object = Invoke-RestMethod -Uri "https://meeting.tencent.com/web-service/query-app-update-info/?os=Windows&app_publish_channel=TencentInside&sdk_id=0300000000&from=2&appver=$($Task.LastState.Version ?? '3.19.22.426')"

if ($Object.upgrade_policy -eq 0) {
  $Task.Logging("The last version $($Task.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.package_url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.features_description | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
}
