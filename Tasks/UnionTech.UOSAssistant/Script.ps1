$Object = Invoke-WebRequest -Uri 'https://www.deepin.org/index/assistant' | ConvertFrom-Html

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object.SelectSingleNode('/html/body/d-root/d-index/div[1]/div/div[2]/div/a').Attributes['href'].Value
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

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
