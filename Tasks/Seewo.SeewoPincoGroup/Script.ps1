$Object1 = $Global:DumplingsStorage.SeewoApps['SeewoPinco']

# Version
$this.CurrentState.Version = $Object1.softInfos.Where({ $_.softCode -eq 'seewoPincoGroup' }, 'First')[0].softVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.softInfos.Where({ $_.softCode -eq 'seewoPincoGroup' }, 'First')[0].downloadUrl
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
