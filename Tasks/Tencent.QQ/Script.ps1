$Object = Invoke-WebRequest -Uri 'https://im.qq.com/pcqq' | ConvertFrom-Html

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object.SelectSingleNode('//*[@class="download"][1]').Attributes['href'].Value.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object.SelectSingleNode('//*[@class="banner-container__box-desc"][1]').InnerText,
  '(\d{4}年\d{1,2}月\d{1,2}日)'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.SelectNodes('//*[@class="features"]').InnerText | Format-Text
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
