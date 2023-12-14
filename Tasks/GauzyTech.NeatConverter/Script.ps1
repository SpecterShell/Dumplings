$Object = Invoke-WebRequest -Uri 'https://www.neat-reader.cn/downloads/converter' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('/html/body/div[2]/section[1]/section/div/p[2]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.SelectSingleNode('/html/body/div[2]/section[1]/section/div/a').Attributes['href'].Value | ConvertTo-UnescapedUri
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
