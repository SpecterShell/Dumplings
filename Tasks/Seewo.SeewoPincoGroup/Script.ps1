$Object = $LocalStorage.SeewoApps['SeewoPinco']

# Version
$this.CurrentState.Version = $Object.softInfos.Where({ $_.softCode -eq 'seewoPincoGroup' }).softVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.softInfos.Where({ $_.softCode -eq 'seewoPincoGroup' }).downloadUrl
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
