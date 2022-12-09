$Object = Invoke-WebRequest -Uri 'https://www.jisupdfeditor.com/' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('//*[@id="banner"]/div/div[2]/ul/li[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# RealVersion
$Task.CurrentState.RealVersion = [regex]::Match($Task.CurrentState.Version, '(\d+\.\d+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.SelectSingleNode('//*[@id="banner"]/div/div[2]/a').Attributes['href'].Value
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object.SelectSingleNode('//*[@id="banner"]/div/div[2]/ul/li[2]').InnerText,
  '(\d{4}-\d{1,2}-\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
}
