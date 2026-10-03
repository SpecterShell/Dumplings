$Prefix = 'https://www.opendesign.com/guestfiles/oda_viewer'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.msi') } catch {} }, 'First')[0].href
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'Auto'
    ReadVersion = { param($Path) Read-ProductVersionFromMsi -Path $Path }
  })
$this.CompleteInstallerUpdates($Result)
