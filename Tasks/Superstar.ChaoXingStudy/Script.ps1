$Object = Invoke-RestMethod -Uri 'https://apps.chaoxing.com/apis/apk/apkInfos.jspx?apkid=com.chaoxing.pc'

# Version
$this.CurrentState.Version = $Object.msg.apkInfo.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.msg.apkInfo.downloadurl
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.msg.apkInfo.message | Split-LineEndings | Select-Object -Skip 1 | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
