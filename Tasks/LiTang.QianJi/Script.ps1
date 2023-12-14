$Object1 = Invoke-RestMethod -Uri 'https://gitee.com/qianjigroup/qianji-public-test/raw/master/upgrade-windows.txt'

# Version
$Task.CurrentState.Version = $Object1.versionName

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.downloadUrl
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.changeLogs | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://docs.qianjiapp.com/change-log/change_log_pc.html' | ConvertFrom-Html

    try {
      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@id='book-search-results']/div[1]/section/h2[contains(./text(), '$($Task.CurrentState.Version)-$($Object1.versionCode)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = $ReleaseNotesNode.SelectSingleNode('./following-sibling::p[1]').InnerText | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $Task.Logging("No ReleaseTime for version $($Task.CurrentState.Version)", 'Warning')
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
