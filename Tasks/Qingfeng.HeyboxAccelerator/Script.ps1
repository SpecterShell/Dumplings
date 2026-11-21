$Object1 = Invoke-RestMethod -Uri 'https://accoriapi.xiaoheihe.cn/proxy/pc_has_new_version/?os_type=pc_proxy'

# Version
$this.CurrentState.Version = $Object1.result.new_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.result.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.result.change_log | ConvertFrom-Html | Get-TextContent | Format-Text
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
