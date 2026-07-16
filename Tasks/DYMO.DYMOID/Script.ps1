$Object1 = Invoke-RestMethod -Uri 'https://download.dymo.com/dymo/Software/DYMO%20ID/swupdate/DZUpdate.en.xml'

# Version
$this.CurrentState.Version = $Object1.dz_updates.desktop_sw_update.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.dz_updates.desktop_sw_update.download_url | ConvertTo-UnescapedUri | ConvertTo-Https
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
