$Object1 = Invoke-RestMethod -Uri 'https://www.splayer.org/stable/latest.json'

# Version
$this.CurrentState.Version = $Object1.name

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.files.win32.url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.createdAt.ToUniversalTime()

$ReleaseNotes = $Object1.releaseNotes.Split('<!---->')
# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotes[0] | Format-Text
}
# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotes[1] | Format-Text
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
