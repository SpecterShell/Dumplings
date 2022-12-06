$Object = Invoke-WebRequest -Uri 'https://download.flvcd.com/' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('/html/body/table/tr[4]/td/table/tr[2]/td[1]/div/a/span/text()').InnerText,
  'v([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.SelectSingleNode('/html/body/table/tr[4]/td/table/tr[2]/td[1]/div/a').Attributes['href'].Value
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object.SelectSingleNode('/html/body/table/tr[4]/td/table/tr[2]/td[1]/p[1]/text()[1]').InnerText,
  '(\d{4}-\d{1,2}-\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$ReleaseNotes = $Object.SelectSingleNode('/html/body/table/tr[4]/td/table/tr[3]/td/pre').InnerText -csplit '硕鼠更新日志.+' |
  Where-Object -FilterScript { $_.Contains($Task.CurrentState.Version) } |
  Format-Text
if ($ReleaseNotes) {
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $ReleaseNotes | Split-LineEndings | Select-Object -Skip 1 | Format-Text
  }
} else {
  Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
}
