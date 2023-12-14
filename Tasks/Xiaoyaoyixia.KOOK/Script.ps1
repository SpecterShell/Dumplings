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
