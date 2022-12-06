$Object = Invoke-WebRequest -Uri 'https://platform.wps.cn/' | ConvertFrom-Html

# Installer
$InstallerUrl = $Object.SelectSingleNode('//*[@id="nav"]/div/div/a[2]').Attributes['href'].Value
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = '11.1.0.' + [regex]::Match($Task.CurrentState.InstallerUrl, 'WPS_Setup_(\d+)\.exe').Groups[1].Value

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object.SelectSingleNode('//*[@id="intro"]/div[2]/div[1]/div[2]/div[1]/span[1]/text()').InnerText,
  '(\d{4}\.\d{1,2}\.\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

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
