$InstallerUrl = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://klant.afas.nl/update-center/downloads'
  Read-PlaywrightLocator -Page $Page -Selector 'xpath=//a[contains(@href, ".exe") and contains(@href, "PccSetup7")]' -Property Attribute -AttributeName href
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerInfo = Get-InstallShieldMsiInfo -Path $InstallerFile -Name 'Profit Communication Center.msi'
      # RealVersion
      $this.CurrentState.RealVersion = $InstallerInfo.ProductVersion
    }

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
