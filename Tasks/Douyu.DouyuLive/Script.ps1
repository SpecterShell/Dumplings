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
