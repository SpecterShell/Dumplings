$Prefix = 'https://he3-1309519128.cos.accelerate.myqcloud.com/'

$Object = Invoke-RestMethod -Uri "${Prefix}latest/latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix + $this.CurrentState.Version + '/' + $Object.files.Where({ $_.url.Contains('ia32') })[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Prefix + $this.CurrentState.Version + '/' + $Object.files.Where({ $_.url.Contains('x64') })[0].url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = (Get-Date -Date $Object.releaseDate).ToUniversalTime()

# ReleaseNotes (zh-CN)
if ($Object.releaseNotes) {
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Object.releaseNotes | Format-Text
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
