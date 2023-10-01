# x86
$Object1 = Invoke-RestMethod -Uri "https://download.flyele.net/v1/downloads/upgrade_version?platform=5&version_number=$($Task.LastState.Version ?? '1.8.4')"
# x64
$Object2 = Invoke-RestMethod -Uri "https://download.flyele.net/v1/downloads/upgrade_version?platform=4&version_number=$($Task.LastState.Version ?? '1.8.4')"

# Version
$Task.CurrentState.Version = $Object2.data.version_number

if ($Object1.data.version_number -ne $Object2.data.version_number) {
  Write-Host -Object "Task $($Task.Name): Distinct versions detected" -ForegroundColor Yellow
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
