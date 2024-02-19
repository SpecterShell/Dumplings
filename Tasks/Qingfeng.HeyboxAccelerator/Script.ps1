$Object1 = Invoke-RestMethod -Uri 'https://accoriapi.xiaoheihe.cn/proxy/pc_has_new_version/'

# Version
$this.CurrentState.Version = $Object1.result.new_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.result.url
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.result.change_log | ConvertFrom-Html | Get-TextContent | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
