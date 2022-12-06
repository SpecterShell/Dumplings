$Object1 = Invoke-WebRequest -Uri 'https://www.360totalsecurity.com/en/360zip/' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="primary-actions"]/p/span').InnerText,
  '([\d\.]+)'
).Groups[1].Value

$Object2 = Invoke-WebRequest -Uri 'https://www.360totalsecurity.com/en/download-free-360-zip/' | ConvertFrom-Html

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https:' + $Object2.SelectSingleNode('//*[@id="download-intro"]/div[1]/a').Attributes['href'].Value
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # TODO: Extract cabinet file

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
