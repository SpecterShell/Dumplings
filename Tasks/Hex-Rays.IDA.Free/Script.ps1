$Object1 = Invoke-RestMethod -Uri 'https://www.hex-rays.com/cgi-bin/oracle.cgi?prod0=IDAFRENW&ver0=0.0.0&prod1=IDAFRECW&ver1=0.0.0&prod2=IDAFREFW&ver2=0.0.0&vercheck=1' | ConvertFrom-Ini
$Object2 = Invoke-WebRequest -Uri 'https://hex-rays.com/ida-free/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Object1.IDAFRE.ver

# RealVersion
$this.CurrentState.RealVersion = [regex]::Match($this.CurrentState.Version, '^(\d+\.\d+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.SelectSingleNode('//*[@id="download"]/div/div/div[2]/div/div[1]/p/a').Attributes['href'].Value
  ProductCode  = "IDA Freeware $($this.CurrentState.RealVersion)"
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
    $this.Submit()
  }
}
