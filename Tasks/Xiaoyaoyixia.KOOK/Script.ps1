$Object1 = Invoke-RestMethod -Uri 'https://www.kookapp.cn/api/v2/updates/latest-version?platform=windows'

# Version
$this.CurrentState.Version = $Object1.number

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.created_at | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.direction | Split-LineEndings | Select-Object -Skip 1 | Format-Text
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
