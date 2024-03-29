$Object1 = Invoke-WebRequest -Uri "https://fanyiapp.cdn.bcebos.com/fanyi-client/update/latest.yml?noCache=$(Get-Random)" | Read-ResponseContent | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.files[0].url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact(
  $Object1.releaseDate,
  "ddd MMM dd yyyy HH:mm:ss 'GMT'K '(GMT'K')'",
  (Get-Culture -Name 'en-US')
).ToUniversalTime()

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.detail | Format-Text | ConvertTo-UnorderedList
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
