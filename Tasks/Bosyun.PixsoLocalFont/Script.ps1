$Object = Invoke-WebRequest -Uri 'https://pixso.cn/download/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('//*[contains(@class, "apps-item") and contains(./div[3]/div[1]/text(), "本地字体助手")]/p[2]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.SelectSingleNode('//*[contains(@class, "apps-item") and contains(./div[3]/div[1]/text(), "本地字体助手")]/div[1]').Attributes['data-href'].Value
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
