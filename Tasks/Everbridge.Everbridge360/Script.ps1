$Object1 = Invoke-RestMethod -Uri 'https://download.everbridge.net/files/windows/everbridge360.appinstaller'

# Version
$this.CurrentState.Version = $Object1.AppInstaller.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = 'https://download.everbridge.net/files/windows/Everbridge360.msi'
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msix'
  InstallerUrl  = 'https://download.everbridge.net/files/windows/Everbridge360.msix'
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
