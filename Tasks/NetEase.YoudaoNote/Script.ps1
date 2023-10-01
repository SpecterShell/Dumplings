$Prefix = 'https://artifact.lx.netease.com/download/ynote-electron/'

$Object = Invoke-WebRequest -Uri "${Prefix}latest-windows.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | Read-ResponseContent | ConvertFrom-Yaml

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix + $Object.files[0].url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.releaseDate | Get-Date -AsUTC

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = ($Object.releaseNotes | ConvertTo-LF | Format-Text) -creplace '(?m)_+$', ''
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
