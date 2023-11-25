$Object = (Invoke-RestMethod -Uri 'https://www.wps.cn/platformUrls').productList.Where({ $_.productId -eq 58 })

# Version
$Task.CurrentState.Version = $Object.productVcode

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.productButtonUrl
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.productDisplaydate | Get-Date -Format 'yyyy-MM-dd'

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
