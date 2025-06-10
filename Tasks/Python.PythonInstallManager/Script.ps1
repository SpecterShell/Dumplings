$Object1 = Invoke-RestMethod -Uri 'https://www.python.org/ftp/python/pymanager/pymanager.appinstaller'

# Version
$this.CurrentState.Version = $Object1.AppInstaller.MainPackage.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msix'
  InstallerUrl  = $Object1.AppInstaller.MainPackage.Uri
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = $Object1.AppInstaller.MainPackage.Uri -replace '\.msix$', '.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
