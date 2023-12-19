# International
$Object1 = Invoke-WebRequest -Uri 'https://www.hihonor.com/global/tech/honor-suite/' | ConvertFrom-Html
$Version1 = [regex]::Match(
  $Object1.SelectSingleNode('//*[@class="section1"]/div[1]/div[2]/p[1]/span[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# Chinese
$Object2 = Invoke-WebRequest -Uri 'https://www.hihonor.com/cn/tech/honor-suite/' | ConvertFrom-Html
$Version2 = [regex]::Match(
  $Object2.SelectSingleNode('//*[@class="section1"]/div[1]/div[2]/p[1]/span[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

$Identical = $true
if ($Version1 -ne $Version2) {
  $Task.Logging('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$Task.CurrentState.Version = $Version2

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//*[@class="section1"]/div[1]/div[2]/div[1]/a[1]').Attributes['href'].Value
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object2.SelectSingleNode('//*[@class="section1"]/div[1]/div[2]/div[1]/a[1]').Attributes['href'].Value
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object2.SelectSingleNode('//*[@class="section1"]/div[1]/div[2]/p[1]/span[1]').InnerText,
  '(\d{4}\.\d{1,2}\.\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $Task.Submit()
  }
}
