$Object1 = Invoke-RestMethod -Uri 'https://releases.arc.net/windows/prod/Arc.appinstaller'
# $Object2 = Invoke-RestMethod -Uri 'https://releases.arc.net/windows/prod/Arc.arm64.appinstaller'

# Version
$this.CurrentState.Version = $Object1.AppInstaller.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.AppInstaller.MainPackage.Uri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object1.AppInstaller.MainPackage.Uri.Replace('x64', 'arm64')
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
