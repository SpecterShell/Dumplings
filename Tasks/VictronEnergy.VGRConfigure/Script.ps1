# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Global:DumplingsStorage.VictronEnergyPrefix $Global:DumplingsStorage.VictronEnergyDownloadPage.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('VGR_Configure_Setup') } catch {} }, 'First')[0].href
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
