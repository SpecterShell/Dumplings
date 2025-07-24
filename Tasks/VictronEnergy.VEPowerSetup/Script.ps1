$Object1 = Invoke-WebRequest -Uri 'https://updates.victronenergy.com/feeds/ve-power-setup/windows/version.txt'

# Version
$this.CurrentState.Version = $Object1.Content.Trim().TrimEnd('_')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://updates.victronenergy.com/feeds/ve-power-setup/windows/VEPowerSetupInstaller.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
