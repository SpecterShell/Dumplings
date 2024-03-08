$Object1 = $Global:DumplingsStorage.SeewoApps['EasiAction']

# Version
$this.CurrentState.Version = $Object1.softInfos[0].softVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.softInfos[0].downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
