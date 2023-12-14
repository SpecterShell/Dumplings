$Object = Invoke-WebRequest -Uri 'https://cdn.soft.360.cn/static/baoku/info_7_0/softinfo_104126128.html' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = $Object.SelectSingleNode('//*[@id="app-data"]/div[3]/div[2]/ul/li[2]/span[2]').InnerText.Trim()

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.SelectSingleNode('//*[@id="download_btn"]').Attributes['data-downurl'].Value | ConvertTo-Https
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object.SelectSingleNode('//*[@id="app-data"]/div[3]/div[2]/ul/li[4]/span[2]').InnerText,
  '(\d{4}-\d{1,2}-\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.SelectSingleNode('//*[@id="doc"]/div[3]/div[3]/div[2]/div') | Get-TextContent | Format-Text
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
