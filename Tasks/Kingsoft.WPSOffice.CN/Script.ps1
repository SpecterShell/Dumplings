$Object1 = (Invoke-RestMethod -Uri 'https://www.wps.cn/platformUrls').productList.Where({ $_.productId -eq 58 }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.productVcode

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.productButtonUrl
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.productDisplaydate | Get-Date -Format 'yyyy-MM-dd'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
