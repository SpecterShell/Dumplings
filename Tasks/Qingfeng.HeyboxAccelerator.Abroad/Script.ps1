$Object1 = Invoke-RestMethod -Uri 'https://accoriapi.xiaoheihe.cn/proxy/pc_has_new_version/?download_source=abroad'

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
