$Object = Invoke-RestMethod -Uri 'https://voovmeeting.com/wemeet-webapi/v2/config/query-download-info' -Method Post -Body (
  @{
    instance = 'windows'
    type     = '1410000197'
  } | ConvertTo-Json -Compress -AsArray
)

# Version
$Task.CurrentState.Version = $Object.data[0].version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.data[0].url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.data[0].sub_date | Get-Date -Format 'yyyy-MM-dd'

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
