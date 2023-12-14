$Object = Invoke-RestMethod -Uri 'https://tron.jiyunhudong.com/api/sdk/check_update?pid=6922326164589517070&branch=master&buildId=&uid='

# Version
$Task.CurrentState.Version = $Object.data.manifest.win32.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.data.manifest.win32.urls
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.data.manifest.win32.extra.uploadDate | ConvertFrom-UnixTimeMilliseconds

# ReleaseNotes (zh-CN)
# $Task.CurrentState.Locale += [ordered]@{
#   Locale = 'zh-CN'
#   Key    = 'ReleaseNotes'
#   Value  = $Object.data.releaseNote | Format-Text
# }

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
}
