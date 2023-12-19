$Object = Invoke-WebRequest -Uri 'https://consumer.huawei.com/cn/support/pc-clone/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('//*[@class="txt-1"]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object.SelectSingleNode('//*[@class="buttoncontent"]/a').Attributes['href'].Value
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $this.CurrentState.RealVersion = [regex]::Match(
      (Invoke-WebRequest -Uri $InstallerUrl -Method Head).Headers.'Content-Disposition',
      '([\d\.]+\(.+?\))\.exe'
    ).Groups[1].Value

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
