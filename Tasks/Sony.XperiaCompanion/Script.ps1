$Object1 = Invoke-RestMethod -Uri 'https://app.swup.update.sony.net/xperia-companion/update-application/windows/manifest.json'

# Version
$this.CurrentState.Version = $Object1.updateApplication.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://app.swup.update.sony.net/xperia-companion/installers/latest/Xperia_Companion.exe'
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
