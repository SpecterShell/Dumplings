if ($Global:DumplingsStorage.LocklizardApps.Contains('PDCWriter6')) {
  $this.Log('Next major version available', 'Warning')
}

# Version
$this.CurrentState.Version = $Global:DumplingsStorage.LocklizardApps.PDCWriter5.Vers

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Global:DumplingsStorage.LocklizardApps.PDCWriter5.Url
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
