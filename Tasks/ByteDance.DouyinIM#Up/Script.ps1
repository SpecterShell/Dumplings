$Object = Invoke-RestMethod -Uri 'https://tron.jiyunhudong.com/api/sdk/check_update?pid=7094550955558967563&branch=release&buildId=&uid='

# Version
$Task.CurrentState.Version = $Object.data.manifest.win32.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object.data.manifest.win32.urls.Where({ $_.region -eq 'cn' }).path.ia32
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object.data.manifest.win32.urls.Where({ $_.region -eq 'cn' }).path.x64
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.data.manifest.win32.extra.uploadDate | ConvertFrom-UnixTimeMilliseconds

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.releaseNote | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
}
