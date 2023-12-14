$Object1 = Invoke-RestMethod -Uri 'https://www.iflyrec.com/UpdateService/v1/updates/hardware/deltaPatch/check' -Method Post -Body (
  @{
    clientVersion = $Task.LastState.Version ?? '2.0.0495'
    deviceType    = 'Windows'
    platform      = 6
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

if ($Object1.biz.update -eq 0) {
  $Task.Logging("The last version $($Task.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# Version
$Task.CurrentState.Version = $Object1.biz.latestVersion

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://www.iflyrec.com/download/tjzs/win'
}

# Sometimes the installer does not match the version
if (-not $InstallerUrl.Contains($Task.CurrentState.Version)) {
  $Task.Logging('The installer does not match the version', 'Warning')

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
