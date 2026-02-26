$Object1 = Invoke-WebRequest -Uri 'https://lt-sampling.kuracloud.com/lt-sampling.appinstaller' | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.AppInstaller.Version

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
