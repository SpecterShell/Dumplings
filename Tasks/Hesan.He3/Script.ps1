$Prefix = 'https://he3-1309519128.cos.accelerate.myqcloud.com/'

$Object = Invoke-RestMethod -Uri "${Prefix}latest/latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix + $Task.CurrentState.Version + '/' + $Object.files.Where({ $_.url.Contains('ia32') })[0].url
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Prefix + $Task.CurrentState.Version + '/' + $Object.files.Where({ $_.url.Contains('x64') })[0].url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = (Get-Date -Date $Object.releaseDate).ToUniversalTime()

# ReleaseNotes (zh-CN)
if ($Object.releaseNotes) {
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Object.releaseNotes | Format-Text
  }
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
