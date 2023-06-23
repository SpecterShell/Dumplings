$Object1 = Invoke-RestMethod -Uri 'https://www.iflyrec.com/UpdateService/v1/updates/hardware/deltaPatch/check' -Method Post -Body (
  @{
    clientVersion = $Task.LastState.Version ?? '2.0.0495'
    deviceType    = 'Windows'
    platform      = 6
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

# Version
$Task.CurrentState.Version = $Object1.biz.latestVersion

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://www.iflyrec.com/download/tjzs/win'
}

# Sometimes the installer does not match the version
if (-not $InstallerUrl.Contains($Task.CurrentState.Version)) {
  Write-Host -Object "Task $($Task.Name): The installer does not match the version" -ForegroundColor Yellow

  # Version
  $Task.CurrentState.Version = [regex]::Match($InstallerUrl, '_v([\d\.]+)').Groups[1].Value
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.biz.latestVersionInfo.Split('&')[0] | Format-Text
}

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.biz.latestVersionInfo.Split('&')[1] | Format-Text
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
