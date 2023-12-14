$Object = Invoke-RestMethod -Uri 'https://tron.jiyunhudong.com/api/sdk/check_update?pid=6888137292980951303&uid=&branch=master&buildId='

# Version
$Task.CurrentState.Version = $Object.data.manifest.win32.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object.data.manifest.win32.extra.x86.installerUrl
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object.data.manifest.win32.extra.x64.installerUrl
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = "`"$($Object.data.releaseNote)`"" | ConvertFrom-Json | Format-Text
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
