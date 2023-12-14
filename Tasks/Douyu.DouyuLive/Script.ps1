$Object = Invoke-RestMethod -Uri 'https://venus.douyucdn.cn/venus/release/pc/checkPackage?appCode=Douyu_Live_PC_Client'

# Version
$Task.CurrentState.Version = $Object.data.versionName

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.data.fileUrl
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.data.updateTime | ConvertFrom-UnixTimeSeconds

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.changelog | Format-Text
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
