$Object1 = (Invoke-RestMethod -Uri 'https://www.wps.cn/platformUrls').productList.Where({ $_.productId -eq 58 }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.productVcode

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.productButtonUrl
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.productDisplaydate | Get-Date -Format 'yyyy-MM-dd'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
