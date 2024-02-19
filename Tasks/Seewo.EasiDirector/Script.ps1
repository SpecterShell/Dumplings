$Object1 = $LocalStorage.SeewoApps['EasiDirector']

# Version
$this.CurrentState.Version = $Object1.softInfos[0].softVersion

# RealVersion
$this.CurrentState.RealVersion = '1.0.0.0'

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
