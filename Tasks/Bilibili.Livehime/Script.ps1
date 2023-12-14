$Object1 = Invoke-RestMethod -Uri 'https://api.live.bilibili.com/xlive/app-blink/v1/liveVersionInfo/getHomePageLiveVersion?system_version=2'

# Version
$Task.CurrentState.Version = $Object1.data.curr_version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.download_url
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.instruction | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-RestMethod -Uri 'https://api.live.bilibili.com/client/v1/LiveHime/getVerList?type=3'

    $ReleaseNotesObject = $Object2.data.list.Where({ $_.title.Contains($Task.CurrentState.Version) })
    if ($ReleaseNotesObject) {
      # ReleaseTime
      $Task.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesObject.title, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } else {
      $Task.Logging("No ReleaseTime for version $($Task.CurrentState.Version)", 'Warning')
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
