$Object = Invoke-WebRequest -Uri 'https://platform.wps.cn/' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = $Object.SelectSingleNode('//*[@id="intro"]/div[2]/div[1]/div[2]/div[1]/span[1]/span[1]').InnerText.Trim()

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://platform.wps.cn/download/query?os=win&os_version=Windows%2010%20or%20Windows%20Server%202016'
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object.SelectSingleNode('//*[@id="intro"]/div[2]/div[1]/div[2]/div[1]/span[1]/span[2]').InnerText,
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
