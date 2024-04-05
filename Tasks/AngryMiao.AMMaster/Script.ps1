$Object1 = Invoke-RestMethod -Uri 'https://diy.angrymiao.com/api/version-manager/history-version?app_code=AM_Master&platform=windows'

# Version
$this.CurrentState.Version = $Object1.data[0].version -replace '^V'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.data[0].url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.data[0].create_time.ToUniversalTime()

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data[0].description_en | Format-Text
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data[0].description | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
