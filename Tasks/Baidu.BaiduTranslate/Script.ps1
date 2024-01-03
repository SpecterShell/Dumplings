$Object1 = Invoke-WebRequest -Uri "https://fanyiapp.cdn.bcebos.com/fanyi-client/update/latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | Read-ResponseContent | ConvertFrom-Yaml

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
