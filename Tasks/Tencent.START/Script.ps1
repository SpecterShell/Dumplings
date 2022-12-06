$Object = (Invoke-RestMethod -Uri 'https://api.start.qq.com/cfg/get?biztypes=windows-update-info-start').configs.'windows-update-info-start'.value | ConvertFrom-Json

# Version
$Task.CurrentState.Version = $Object.latestversion

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.downloadurl
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.updatedate | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.whatsnew | Format-Text
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
