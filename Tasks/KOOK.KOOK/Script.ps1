$Object = Invoke-RestMethod -Uri 'https://www.kookapp.cn/api/v2/updates/latest-version?platform=windows'

# Version
$Task.CurrentState.Version = $Object.number

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.created_at | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.direction | Split-LineEndings | Select-Object -Skip 1 | Format-Text
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
