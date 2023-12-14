$Object = Invoke-RestMethod -Uri 'https://back2.hellofont.cn/ziyou/ClientManagement/api/ClientVersion/LatestClientVersionItem' -Method Post -Body @{ PlatformId = 0 }

# Version
$Task.CurrentState.Version = $Object.Version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.Url | ConvertTo-UnescapedUri
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [datetime]::ParseExact($Object.TimeStamp, 'yyyyMMddHHmmssfff', $null) | ConvertTo-UtcDateTime -Id 'China Standard Time'

# ReleaseNotes (zh-CN)
$ReleaseNotesList = @()
if ($Object.News) {
  $ReleaseNotesList += '新增功能：'
  $ReleaseNotesList += $Object.News | ConvertTo-UnorderedList | Format-Text
}
if ($Object.Bugs) {
  $ReleaseNotesList += '问题修复：'
  $ReleaseNotesList += $Object.Bugs | ConvertTo-UnorderedList | Format-Text
}
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesList | Format-Text
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
