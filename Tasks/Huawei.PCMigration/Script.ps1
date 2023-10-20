$Object = Invoke-WebRequest -Uri 'https://consumer.huawei.com/cn/support/pc-clone/' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('//*[@class="txt-1"]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object.SelectSingleNode('//*[@class="buttoncontent"]/a').Attributes['href'].Value
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = [regex]::Match(
      (Invoke-WebRequest -Uri $InstallerUrl -Method Head).Headers.'Content-Disposition',
      '([\d\.]+\(.+?\))\.exe'
    ).Groups[1].Value

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
