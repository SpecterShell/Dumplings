$Object = Invoke-RestMethod -Uri 'https://infobox.cubejoy.com/data.ashx?JsonData=%7B%22Code%22:%2210030%22%7D'

# Version
$Task.CurrentState.Version = $Object.result.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.cubejoy.com/app/$($Task.CurrentState.Version)/CubeSetup_v$($Task.CurrentState.Version).exe"
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-HK'
  InstallerUrl    = "https://download.cubejoy.com/app/$($Task.CurrentState.Version)/CubeSetup_HK_TC_v$($Task.CurrentState.Version).exe"
}

$ReleaseNotes = $Object.result.whatisnew | Split-LineEndings

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotes[0], '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotes | Select-Object -Skip 1 | Format-Text
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
