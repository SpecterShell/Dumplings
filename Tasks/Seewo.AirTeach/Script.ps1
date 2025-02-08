$Object1 = $Global:DumplingsStorage.SeewoApps['AirTeach']

# Version
$this.CurrentState.Version = $Object1.softInfos.Where({ $_.useSystem -eq 1 }, 'First')[0].softVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.softInfos.Where({ $_.useSystem -eq 1 }, 'First')[0].downloadUrl
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
