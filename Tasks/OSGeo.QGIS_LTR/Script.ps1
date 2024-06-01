$Object1 = Invoke-RestMethod -Uri 'https://github.com/qgis/QGIS-Website/raw/master/source/schedule.py'

$Release = [regex]::Match($Object1, "ltrrelease\s*=\s*'(.+?)'").Groups[1].Value
$Binary = [regex]::Match($Object1, "ltrbinary\s*=\s*'(.+?)'").Groups[1].Value

# Version
$this.CurrentState.Version = "${Release}-${Binary}"

# RealVersion
$this.CurrentState.RealVersion = $Release

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://qgis.org/downloads/QGIS-OSGeo4W-${Release}-${Binary}.msi"
}

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
