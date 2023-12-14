$Object = (Invoke-RestMethod -Uri 'https://www.wps.cn/platformUrls').productList.Where({ $_.productId -eq 58 })

# Version
$Task.CurrentState.Version = $Object.productVcode

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.productButtonUrl
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.productDisplaydate | Get-Date -Format 'yyyy-MM-dd'

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
