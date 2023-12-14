$Object = Invoke-WebRequest -Uri 'https://www.wps.cn/product/kingsoftpdf' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('/html/body/div[1]/div/div[2]/p').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.SelectSingleNode('/html/body/div[1]/div/div[2]/a').Attributes['href'].Value
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object.SelectSingleNode('//html/body/div[1]/div/div[2]/p').InnerText,
  '(\d{4}\.\d{1,2}\.\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

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
