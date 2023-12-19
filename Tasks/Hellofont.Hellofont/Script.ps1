$Object = Invoke-RestMethod -Uri 'https://back2.hellofont.cn/ziyou/ClientManagement/api/ClientVersion/LatestClientVersionItem' -Method Post -Body @{ PlatformId = 0 }

# Version
$this.CurrentState.Version = $Object.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.Url | ConvertTo-UnescapedUri
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object.TimeStamp, 'yyyyMMddHHmmssfff', $null) | ConvertTo-UtcDateTime -Id 'China Standard Time'

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
