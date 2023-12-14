$Object1 = Invoke-WebRequest -Uri 'https://www.taglyst.com/download-next' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//a[contains(./span/text(), "Windows版")]/preceding-sibling::span[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//a[contains(./span/text(), "Windows版")]').Attributes['href'].Value
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
