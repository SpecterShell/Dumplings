$Object = (Invoke-RestMethod -Uri 'https://api.start.qq.com/cfg/get?biztypes=windows-update-info').configs.'windows-update-info'.value | ConvertFrom-Json

# Version
$Task.CurrentState.Version = $Object.latestversion

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.downloadurl.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.updatedate | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.whatsnew | Format-Text
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
