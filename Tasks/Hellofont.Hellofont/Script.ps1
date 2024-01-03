$Object1 = Invoke-RestMethod -Uri 'https://back2.hellofont.cn/ziyou/ClientManagement/api/ClientVersion/LatestClientVersionItem' -Method Post -Body @{ PlatformId = 0 }

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Url | ConvertTo-UnescapedUri
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact(
  $Object1.TimeStamp,
  'yyyyMMddHHmmssfff',
  $null
) | ConvertTo-UtcDateTime -Id 'China Standard Time'

$ReleaseNotesList = @()
if ($Object1.News) {
  $ReleaseNotesList += '新增功能：'
  $ReleaseNotesList += $Object1.News | ConvertTo-UnorderedList | Format-Text
}
if ($Object1.Bugs) {
  $ReleaseNotesList += '问题修复：'
  $ReleaseNotesList += $Object1.Bugs | ConvertTo-UnorderedList | Format-Text
}
# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesList | Format-Text
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
