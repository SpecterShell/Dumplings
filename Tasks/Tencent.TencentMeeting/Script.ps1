$Object1 = Invoke-RestMethod -Uri 'https://meeting.tencent.com/web-service/query-download-info?q=[{%22package-type%22:%22app%22,%22channel%22:%220300000000%22,%22platform%22:%22windows%22}]&nonce=AAAAAAAAAAAAAAAA'

# Version
$this.CurrentState.Version = $Object1.'info-list'[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.'info-list'[0].url.Replace('.officialwebsite', '')
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.'info-list'[0].'sub-date' | Get-Date -Format 'yyyy-MM-dd'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-RestMethod -Uri "https://meeting.tencent.com/web-service/query-app-update-info/?os=Windows&app_publish_channel=TencentInside&sdk_id=0300000000&from=2&appver=$($this.LastState.Version ?? '3.19.22.426')"

    try {
      if ($Object2.upgrade_policy -eq 0 -or $this.CurrentState.Version -ne $Object2.version) {
        $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      } else {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.features_description | Format-Text
        }
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
