# International
$Object1 = Invoke-RestMethod -Uri "https://intl.meeting.huaweicloud.com/v1/usg/tms/softterm/version/query?userType=cloudlink-windows&currentVersion=$($Task.LastState.Version ?? '9.7.7')"
$Version1 = $Object1.upgradeVersion

# Chinese
$Object2 = Invoke-RestMethod -Uri "https://meeting.huaweicloud.com/v1/usg/tms/softterm/version/query?userType=cloudlink-windows&currentVersion=$($Task.LastState.Version ?? '9.7.7')"
$Version2 = $Object2.upgradeVersion

if ($Version1 -ne $Version2) {
  $Task.Logging('Distinct versions detected', 'Warning')
  $Task.Config.Notes = '检测到不同的版本'
}

# Version
$Task.CurrentState.Version = $Version1

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.versionPath
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object2.versionPath
}

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.versionDescriptionEn | Format-Text
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object2.versionDescription | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 -and $Version1 -eq $Version2 }) {
    $Task.Submit()
  }
}
