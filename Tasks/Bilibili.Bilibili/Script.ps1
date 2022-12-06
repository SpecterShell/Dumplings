$Prefix = 'https://api.bilibili.com/x/elec-frontend/update/'

$Object = Invoke-WebRequest -Uri "${Prefix}latest.yml" | Read-ResponseContent | ConvertFrom-Yaml

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri ($Prefix + $Object.files[0].url) -Headers @{
    appversion = '0.0.0'
  }
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.releaseDate.ToUniversalTime()

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.news | Format-Text
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
