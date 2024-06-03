$Object1 = Invoke-RestMethod -Uri 'https://venus.douyucdn.cn/venus/release/pc/checkPackage?appCode=Douyu_Live_PC_Client'

# Version
$this.CurrentState.Version = $Object1.data.versionName

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.fileUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.updateTime | ConvertFrom-UnixTimeSeconds

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.changelog | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
