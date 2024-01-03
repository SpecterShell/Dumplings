$Object1 = Invoke-WebRequest -Uri 'https://www.wps.cn/product/kingsoftpdf' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/div[1]/div/div[2]/p').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('/html/body/div[1]/div/div[2]/a').Attributes['href'].Value
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match(
  $Object1.SelectSingleNode('//html/body/div[1]/div/div[2]/p').InnerText,
  '(\d{4}\.\d{1,2}\.\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

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
