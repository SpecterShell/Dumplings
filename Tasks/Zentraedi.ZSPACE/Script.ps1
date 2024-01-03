$Object1 = Invoke-RestMethod -Uri 'https://upgrade.zenithspace.net/upgrade_server/v2/check_upgrade?app_id=APP_ZSPACE_DESKTOP_WIN&app_version=V0.0.0&plat=app&skip_app_sync_upgrade=1'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.data.app_version, '([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.download_url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.data.update_time | ConvertTo-UtcDateTime -Id 'China Standard Time'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.version_content | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
