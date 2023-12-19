# International
$Object1 = Invoke-RestMethod -Uri "https://intl.meeting.huaweicloud.com/v1/usg/tms/softterm/version/query?userType=cloudlink-windows&currentVersion=$($Task.LastState.Version ?? '9.7.7')"
if ($Object1.isConsistent) {
  $Task.Logging("The last version for international edition $($Task.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# Chinese
$Object2 = Invoke-RestMethod -Uri "https://meeting.huaweicloud.com/v1/usg/tms/softterm/version/query?userType=cloudlink-windows&currentVersion=$($Task.LastState.Version ?? '9.7.7')"
if ($Object2.isConsistent) {
  $Task.Logging("The last version for Chinese edition $($Task.LastState.Version) is the latest, skip checking", 'Info')
  return
}

if ($Object1.upgradeVersion -ne $Object2.upgradeVersion) {
  $Task.Logging('Distinct versions detected', 'Warning')
}

# Version
$Task.CurrentState.Version = $Object1.upgradeVersion

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
  ({ $_ -ge 3 -and $Object1.upgradeVersion -eq $Object2.upgradeVersion }) {
    $Task.Submit()
  }
}
