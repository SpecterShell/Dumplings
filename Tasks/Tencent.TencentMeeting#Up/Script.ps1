$Object1 = Invoke-RestMethod -Uri "https://meeting.tencent.com/web-service/query-app-update-info/?os=Windows&app_publish_channel=TencentInside&sdk_id=0300000000&from=2&appver=$($this.LastState.Version ?? '3.19.22.426')"

if ($Object1.upgrade_policy -eq 0) {
  $this.Logging("The last version $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.package_url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.features_description | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
}
