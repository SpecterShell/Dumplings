$Object1 = Invoke-RestMethod -Uri 'https://venus.douyucdn.cn/venus/release/pc/checkPackage?appCode=Douyu_Live_PC_Client'

# Version
$this.CurrentState.Version = $Object1.data.versionName

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.fileUrl
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.data.updateTime | ConvertFrom-UnixTimeSeconds

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.changelog | Format-Text
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
