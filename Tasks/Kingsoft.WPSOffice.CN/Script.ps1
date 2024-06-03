$Object1 = (Invoke-RestMethod -Uri 'https://www.wps.cn/platformUrls').productList.Where({ $_.productId -eq 58 }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.productVcode

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.productButtonUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.productDisplaydate | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
