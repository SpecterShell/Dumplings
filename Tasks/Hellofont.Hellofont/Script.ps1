# Download
$Object1 = Invoke-RestMethod -Uri 'https://back2.hellofont.cn/ziyou/ClientManagement/api/ClientVersion/LatestClientVersionItem' -Method Post -Body @{ PlatformId = 0 }
# Upgrade
$Prefix = 'https://hellofont.oss-cn-beijing.aliyuncs.com/Client/Release/'
$Object2 = Invoke-WebRequest -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | Read-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

if ((Compare-Version -ReferenceVersion $Object1.Version -DifferenceVersion $Object2.Version) -gt 0) {
  $Object2.Locale | Where-Object -Property Key -EQ -Value 'ReleaseNotes' | ForEach-Object -Process { $_.Value = $_.Value | ConvertFrom-Html | Get-TextContent | Format-Text }
  $Task.CurrentState = $Object2
} else {
  # Version
  $Task.CurrentState.Version = $Object1.Version

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object1.Url | ConvertTo-UnescapedUri
  }

  # ReleaseTime
  $Task.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.TimeStamp, 'yyyyMMddHHmmssfff', $null) | ConvertTo-UtcDateTime -Id 'China Standard Time'

  # ReleaseNotes (zh-CN)
  $ReleaseNotesList = @()
  if ($Object1.News) {
    $ReleaseNotesList += '新增功能：'
    $ReleaseNotesList += $Object1.News | ConvertTo-UnorderedList | Format-Text
  }
  if ($Object1.Bugs) {
    $ReleaseNotesList += '问题修复：'
    $ReleaseNotesList += $Object1.Bugs | ConvertTo-UnorderedList | Format-Text
  }
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $ReleaseNotesList | Format-Text
  }
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
