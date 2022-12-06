$Object = Invoke-RestMethod -Uri 'https://apps.chaoxing.com/apis/apk/apkInfos.jspx?apkid=com.chaoxing.pc'

# Version
$Task.CurrentState.Version = $Object.msg.apkInfo.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.msg.apkInfo.downloadurl
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.msg.apkInfo.message | Split-LineEndings | Select-Object -Skip 1 | Format-Text
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
