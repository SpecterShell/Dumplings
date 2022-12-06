$Object = Invoke-RestMethod -Uri 'https://yungw.taobao.com/gw/invoke/taobao.jindoucloud.version.check2?clientSysName=Windows+PC&clientName=WangWang&clientVersion=9.12.10C&timestamp=0' -Headers @{ Referer = 'http://www.taobao.com/' }

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.alicdn.com/wangwang/AliIM_taobao_($($Task.CurrentState.Version)).exe"
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.feature | Format-Text
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
