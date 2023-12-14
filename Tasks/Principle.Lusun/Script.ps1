$Prefix = 'https://releases.lusun.com/'

$Object = Invoke-WebRequest -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | Read-ResponseContent | ConvertFrom-Yaml

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix + $Object.files.Where({ $_.url.Contains('ia32') })[0].url
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Prefix + $Object.files.Where({ $_.url.Contains('x64') })[0].url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = (Get-Date -Date $Object.releaseDate).ToUniversalTime()

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.releaseNotes | Split-LineEndings | Select-Object -Skip 1 | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
