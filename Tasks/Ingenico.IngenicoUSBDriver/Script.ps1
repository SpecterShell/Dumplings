$Prefix = 'https://ingenico.com/apac/resources/ingenico-usb-driver-application-and-installation-guide'
$Page = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'nullsoft'
  InstallerUrl        = Join-Uri $Prefix $Page.Links.Where({ try { $_.href -match 'IngenicoUSBDrivers' -and $_.href -match 'setup' -and $_.href.EndsWith('.zip') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

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
