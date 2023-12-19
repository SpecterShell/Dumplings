$Object = (Invoke-RestMethod -Uri 'https://www.wps.cn/platformUrls').productList.Where({ $_.productId -eq 58 })

# Version
$this.CurrentState.Version = $Object.productVcode

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.productButtonUrl
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object.productDisplaydate | Get-Date -Format 'yyyy-MM-dd'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
