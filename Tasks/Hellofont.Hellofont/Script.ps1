$Object1 = Invoke-RestMethod -Uri 'https://back2.hellofont.cn/ziyou/ClientManagement/api/ClientVersion/LatestClientVersionItem' -Method Post -Body @{ PlatformId = 0 }
$Object2 = Invoke-RestMethod -Uri 'https://www.hellofont.cn/api/system/client-channel?platform=windows&channel=official'

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object2.link | ConvertTo-UnescapedUri
}

if (-not $InstallerUrl.Contains($this.CurrentState.Version)) {
  throw "Task $($this.Name): The InstallerUrl`n${InstallerUrl}`ndoesn't contain version $($this.CurrentState.Version)"
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

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
