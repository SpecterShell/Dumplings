# Version and InstallerUrl
$Software = $Global:DumplingsStorage.VictronEnergySoftwareCatalog.Where({ $_.title -eq 'BMV Reader' }, 'First')[0]
$Object1 = Invoke-RestMethod -Uri "$($Global:DumplingsStorage.VictronEnergySoftwareApiPrefix)$($Software.id)/"
$Download = $Object1.sections.accordion.links.Where({ $_.label -match 'BMV Reader' -and $_.url.EndsWith('.zip') }, 'First')[0]

$this.CurrentState.Version = [regex]::Match($Download.label, '^\(([^)]+)\)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = [System.Uri]::new((Join-Uri $Global:DumplingsStorage.VictronEnergyWebsitePrefix $Download.url)).AbsoluteUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "$($Download.url | Split-Path -LeafBase)\setup.msi"
    }
  )
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
