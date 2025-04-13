$Object1 = Invoke-WebRequest -Uri 'https://www.speedtest.net/apps/windows' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match($Object1.SelectSingleNode('//span[@class="u-note"]').InnerText, 'v(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://install.speedtest.net/app/windows/$($this.CurrentState.Version)/speedtestbyookla_x86.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://install.speedtest.net/app/windows/$($this.CurrentState.Version)/speedtestbyookla_x64.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
