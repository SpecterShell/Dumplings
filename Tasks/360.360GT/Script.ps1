$Object1 = Invoke-WebRequest -Uri 'https://browser.360.cn/gt/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/div/div[2]/div[2]/div[1]/p/span').InnerText,
  '(\d+\.\d+\.\d+\.\d+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('/html/body/div/div[2]/div[2]/div[1]/a').Attributes['href'].Value
}

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
