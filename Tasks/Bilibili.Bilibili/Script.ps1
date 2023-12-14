$Prefix = 'https://api.bilibili.com/x/elec-frontend/update/'

$Object = Invoke-WebRequest -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | Read-ResponseContent | ConvertFrom-Yaml

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri ($Prefix + $Object.files[0].url) -Headers @{
    appversion = '0.0.0'
  }
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = (Get-Date -Date $Object.releaseDate).ToUniversalTime()

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.news | Format-Text
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
