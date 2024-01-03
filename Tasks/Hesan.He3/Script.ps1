$Prefix = 'https://he3-1309519128.cos.accelerate.myqcloud.com/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest/latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix + $this.CurrentState.Version + '/' + $Object1.files.Where({ $_.url.Contains('ia32') })[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Prefix + $this.CurrentState.Version + '/' + $Object1.files.Where({ $_.url.Contains('x64') })[0].url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC

# ReleaseNotes (zh-CN)
if ($Object1.releaseNotes) {
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Object1.releaseNotes | Format-Text
  }
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
