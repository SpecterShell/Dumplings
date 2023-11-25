$Object1 = Invoke-WebRequest -Uri 'https://tv.sohu.com/down/index.shtml?downLoad=windows' | Read-ResponseContent -Encoding 'GBK' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//div[contains(@class, "down_winbox")]/div[2]/div/p/span').InnerText,
  '版本号([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl1st -Uri ('https:' + $Object1.SelectSingleNode('//div[contains(@class, "down_winbox")]/div[2]/a').Attributes['href'].Value)
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object1.SelectSingleNode('//div[contains(@class, "down_winbox")]/div[2]/div/p/span').InnerText,
  '(\d{4}-\d{1,2}-\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.SelectNodes('//div[contains(@class, "down_winbox")]/div[2]/div/div') | Get-TextContent | Format-Text
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
