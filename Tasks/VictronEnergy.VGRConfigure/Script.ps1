# Version and InstallerUrl
$Software = $Global:DumplingsStorage.VictronEnergySoftwareCatalog.Where({ $_.title -eq 'Victron Global Remote Configuration tool' }, 'First')[0]
$Object1 = Invoke-RestMethod -Uri "$($Global:DumplingsStorage.VictronEnergySoftwareApiPrefix)$($Software.id)/"
$Download = $Object1.sections.accordion.links.Where({ $_.label -match 'VGR Configure' -and $_.url.EndsWith('.msi') }, 'First')[0]

$this.CurrentState.Version = [regex]::Match($Download.label, '^\(([^)]+)\)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Download.url
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
