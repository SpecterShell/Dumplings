$Object = Invoke-RestMethod -Uri 'https://upgrade.zenithspace.net/upgrade_server/v2/check_upgrade?app_id=APP_ZSPACE_DESKTOP_WIN&app_version=V0.0.0&plat=app&skip_app_sync_upgrade=1'

# Version
$Task.CurrentState.Version = [regex]::Match($Object.data.app_version, 'V([\d\.]+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.data.download_url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.data.update_time | ConvertTo-UtcDateTime -Id 'China Standard Time'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.version_content | Format-Text
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
