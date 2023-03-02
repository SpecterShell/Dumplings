$Object1 = Invoke-RestMethod -Uri 'https://www.hex-rays.com/cgi-bin/oracle.cgi?prod0=IDAFRENW&ver0=0.0.0&prod1=IDAFRECW&ver1=0.0.0&prod2=IDAFREFW&ver2=0.0.0&vercheck=1' | ConvertFrom-Ini
$Object2 = Invoke-WebRequest -Uri 'https://hex-rays.com/ida-free/' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = $Object1.IDAFRE.ver

# RealVersion
$Task.CurrentState.RealVersion = [regex]::Match($Task.CurrentState.Version, '^(\d+\.\d+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.SelectSingleNode('//*[@id="download"]/div/div/div[2]/div/div[1]/p/a').Attributes['href'].Value
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
}
