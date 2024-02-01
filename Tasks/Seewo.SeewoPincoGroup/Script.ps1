$Object1 = $LocalStorage.SeewoApps['SeewoPinco']

# Version
$this.CurrentState.Version = $Object1.softInfos.Where({ $_.softCode -eq 'seewoPincoGroup' }, 'First')[0].softVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.softInfos.Where({ $_.softCode -eq 'seewoPincoGroup' }, 'First')[0].downloadUrl
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
