# International
$Object1 = Invoke-WebRequest -Uri 'https://consumer.huawei.com/en/support/hisuite/' | ConvertFrom-Html
$Version1 = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/div[6]/div/div/div/div[1]/div[1]/div/div[1]/p/text()[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value
# Chinese
$Object2 = Invoke-WebRequest -Uri 'https://consumer.huawei.com/cn/support/hisuite/' | ConvertFrom-Html
$Version2 = [regex]::Match(
  $Object2.SelectSingleNode('/html/body/div[5]/div/div/div/div[1]/div[1]/div/div[1]/p/text()[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

if ($Version1 -ne $Version2) {
  $Task.Logging('Distinct versions detected', 'Warning')
}

# Version
$Task.CurrentState.Version = $Version1

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('/html/body/div[6]/div/div/div/div[1]/div[1]/div/div[1]/a').Attributes['href'].Value
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object2.SelectSingleNode('/html/body/div[5]/div/div/div/div[1]/div[1]/div/div[1]/a').Attributes['href'].Value
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/div[6]/div/div/div/div[1]/div[1]/div/div[1]/p/text()[1]').InnerText,
  '(\d{4}\.\d{1,2}\.\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 -and $Version1 -eq $Version2 }) {
    $Task.Submit()
  }
}
