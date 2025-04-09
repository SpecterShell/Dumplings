$Object1 = Invoke-WebRequest -Uri 'https://upgrade-online.zwsoft.cn/zwcadpersonal/2025/ZwServerUpdateConfig.xml' | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.ServerConfigs.ZWCAD_X64.'zh-CN'.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.ServerConfigs.ZWCAD_X64.'zh-CN'.mspSourceUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.ServerConfigs.ZWCAD_X64.'zh-CN'.content.Replace('^', "`n") | Format-Text
      }

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object1.ServerConfigs.ZWCAD_X64.'zh-CN'.vernum, '(20\d{2}\.\d{2}\.\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
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
