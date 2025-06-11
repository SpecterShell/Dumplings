# Version
$this.CurrentState.Version = $Global:DumplingsStorage.LocklizardApps.PDCWriterS4.Vers

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Global:DumplingsStorage.LocklizardApps.PDCWriterS4.Url
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
