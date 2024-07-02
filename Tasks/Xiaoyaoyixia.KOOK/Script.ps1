$Object1 = Invoke-RestMethod -Uri 'https://www.kookapp.cn/api/v2/updates/latest-version?platform=windows'

# Version
$this.CurrentState.Version = $Object1.number

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.url | Split-Uri -LeftPart Path
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.created_at | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.direction | Split-LineEndings | Select-Object -Skip 1 | Format-Text
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
