$Object = Invoke-RestMethod -Uri 'https://www.redisant.com/ltip/activate/checkUpdate'
# $Object = Invoke-RestMethod -Uri 'https://www.redisant.cn/ltip/activate/checkUpdate'

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$InstallerUrls = $Object.downloadUrl.Split('|')
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrls | Where-Object -FilterScript { $_.Contains('x86') -and $_.EndsWith('.exe') }
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrls | Where-Object -FilterScript { $_.Contains('x64') -and $_.EndsWith('.exe') }
}

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object.enDescribes | Format-Text | ConvertTo-UnorderedList
}
# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.describes | Format-Text | ConvertTo-UnorderedList
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
