$Prefix = 'https://download.kugou.com/'

$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//*[contains(@class, "tuijian_products") and contains(.//*[@class="product_title"], "酷狗电脑版")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.SelectSingleNode('.//*[@class="tuijian_product_version"]').InnerText, '(\d+(\.\d+){1,})').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object2.SelectSingleNode('.//a[@class="tuijian_product_download"]').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.SelectSingleNode('.//*[@class="tuijian_product_description"]').InnerText, '(20\d{2}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
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
