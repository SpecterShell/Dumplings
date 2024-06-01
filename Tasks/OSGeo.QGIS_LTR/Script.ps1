$Object1 = Invoke-WebRequest -Uri 'https://www.qgis.org/en/site/forusers/download.html' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.SelectSingleNode('//div[@id="windows"]//a[contains(@href, ".msi") and contains(@class, "secondary-download-link")]').Attributes['href'].Value
}

# Version
$VersionMatches = [regex]::Match($InstallerUrl, '((\d+\.\d+\.\d+)-\d+)')
$this.CurrentState.Version = $VersionMatches.Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = $VersionMatches.Groups[2].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName = Read-MsiProperty -Path $InstallerFile -Query "SELECT Value FROM Property WHERE Property='ProductName'"
        ProductCode = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi
        UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
      }
    )

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
