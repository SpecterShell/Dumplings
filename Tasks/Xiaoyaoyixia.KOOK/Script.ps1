$Object = Invoke-RestMethod -Uri 'https://www.kookapp.cn/api/v2/updates/latest-version?platform=windows'

# Version
$this.CurrentState.Version = $Object.number

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object.created_at | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.direction | Split-LineEndings | Select-Object -Skip 1 | Format-Text
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
