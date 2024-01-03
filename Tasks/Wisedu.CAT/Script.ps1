$Object1 = Invoke-WebRequest -Uri 'https://cat.wisedu.com/%e6%9c%8d%e5%8a%a1/%e5%ae%a2%e6%88%b7%e7%ab%af%e4%b8%8b%e8%bd%bd/' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.SelectSingleNode('//*[contains(@class,"type-page")]/div/div[1]/a[1]').Attributes['href'].Value | ConvertTo-UnescapedUri
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.]+)_Setup').Groups[1].Value

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
