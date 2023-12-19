$Object1 = Invoke-RestMethod -Uri 'https://meeting.tencent.com/web-service/query-download-info?q=[{%22package-type%22:%22app%22,%22channel%22:%220300000000%22,%22platform%22:%22windows%22}]&nonce=AAAAAAAAAAAAAAAA'

# Version
$Task.CurrentState.Version = $Object1.'info-list'[0].version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.'info-list'[0].url.Replace('.officialwebsite', '')
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.'info-list'[0].'sub-date' | Get-Date -Format 'yyyy-MM-dd'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-RestMethod -Uri "https://meeting.tencent.com/web-service/query-app-update-info/?os=Windows&app_publish_channel=TencentInside&sdk_id=0300000000&from=2&appver=$($Task.LastState.Version ?? '3.19.22.426')"

    try {
      if ($Object2.upgrade_policy -eq 0 -or $Task.CurrentState.Version -ne $Object2.version) {
        $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Info')
      } else {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.features_description | Format-Text
        }
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
