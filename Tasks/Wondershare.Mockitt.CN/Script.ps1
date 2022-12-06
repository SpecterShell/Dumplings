$Object = Invoke-RestMethod -Uri 'https://modao.cc/api/v2/client/desktop/check_update.json?region=CN&version=1.1.0&platform=win32&arch=x64'

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://cdn.modao.cc/Mockitt-win32-ia32-zh-$($Task.CurrentState.Version).exe"
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://cdn.modao.cc/Mockitt-win32-x64-zh-$($Task.CurrentState.Version).exe"
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.pub_date.ToUniversalTime()

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.release_notes_zh | Format-Text
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
