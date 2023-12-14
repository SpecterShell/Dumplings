$Object = Invoke-WebRequest -Uri 'https://pixso.cn/download/' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('//*[contains(@class, "apps-item") and contains(./div[3]/div[1]/text(), "本地字体助手")]/p[2]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.SelectSingleNode('//*[contains(@class, "apps-item") and contains(./div[3]/div[1]/text(), "本地字体助手")]/div[1]').Attributes['data-href'].Value
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
