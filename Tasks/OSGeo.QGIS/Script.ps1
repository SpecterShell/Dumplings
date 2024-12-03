$Object1 = Invoke-RestMethod -Uri 'https://version.qgis.org/version.json'

# Version
$this.CurrentState.Version = "$($Object1.latest.major).$($Object1.latest.minor).$($Object1.latest.patch)-$($Object1.latest.binary)"

# RealVersion
$this.CurrentState.RealVersion = "$($Object1.latest.major).$($Object1.latest.minor).$($Object1.latest.patch)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://qgis.org/downloads/QGIS-OSGeo4W-$($Object1.latest.major).$($Object1.latest.minor).$($Object1.latest.patch)-$($Object1.latest.binary).msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.latest.date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
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
