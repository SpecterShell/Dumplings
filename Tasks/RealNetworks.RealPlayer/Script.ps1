$Object1 = Invoke-RestMethod -Uri 'https://cache-download.real.com/free/windows/installer/stubinst/xml/rp25/stubinst_config_en.xml'

# Version
$this.CurrentState.Version = $Object1.config.'package-list'.package.Where({ $_.id -eq 'rp' }, 'First')[0].pkg_version

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Object1.config.distcodes.baseUri $Object1.config.distcodes.defaultDistcode.defaultOS.defaultLocale.installerpkg.uri | ConvertTo-Https
  ProductCode  = "RealPlayer $($this.CurrentState.Version.Split('.')[0..1] -join '.')"
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
