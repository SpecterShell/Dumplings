$Object = Invoke-RestMethod -Uri 'https://accoriapi.xiaoheihe.cn/proxy/pc_has_new_version/'

# Version
$Task.CurrentState.Version = $Object.result.new_version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.result.url
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.result.change_log | ConvertFrom-Html | Get-TextContent | Format-Text
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
