$Object1 = Invoke-RestMethod -Uri 'https://version.qgis.org/version.json'

# Version
$this.CurrentState.Version = "$($Object1.ltr.major).$($Object1.ltr.minor).$($Object1.ltr.patch)-$($Object1.ltr.binary)"

# RealVersion
$this.CurrentState.RealVersion = "$($Object1.ltr.major).$($Object1.ltr.minor).$($Object1.ltr.patch)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://qgis.org/downloads/QGIS-OSGeo4W-$($Object1.ltr.major).$($Object1.ltr.minor).$($Object1.ltr.patch)-$($Object1.ltr.binary).msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ltr.date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
