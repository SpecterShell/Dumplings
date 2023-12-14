# x86
$Object1 = Invoke-RestMethod -Uri "https://download.flyele.net/v1/downloads/upgrade_version?platform=5&version_number=$($Task.LastState.Version ?? '1.8.4')"
# x64
$Object2 = Invoke-RestMethod -Uri "https://download.flyele.net/v1/downloads/upgrade_version?platform=4&version_number=$($Task.LastState.Version ?? '1.8.4')"

# Version
$Task.CurrentState.Version = $Object2.data.version_number

if ($Object1.data.version_number -ne $Object2.data.version_number) {
  $Task.Logging('Distinct versions detected', 'Warning')
  $Task.Config.Notes = '检测到不同的版本'
}

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.data.downloads.full_version.link_url
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.data.downloads.full_version.link_url
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object2.data.release_note | Format-Text
}

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
