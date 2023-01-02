$Object = Invoke-WebRequest -Uri 'https://www.douyin.com/downloadpage/chat' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('//*[@id="root"]/div/div[2]/div/div[3]/div/div[1]/div/div/div[2]').InnerText.Trim(),
  '最新版本：([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.SelectSingleNode('//*[@id="root"]/div/div[2]/div/div[3]/div/div[1]/div/div/div[1]/a[1]').Attributes['href'].Value
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object.SelectSingleNode('//*[@id="root"]/div/div[2]/div/div[3]/div/div[1]/div/div/div[2]').InnerText.Trim(),
  '更新时间：(\d{4}-\d{1,2}-\d{1,2})'
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
