$Object1 = Invoke-RestMethod -Uri 'https://bim.dalux.com/Desktop/Dalux.appinstaller'

# Version
$this.CurrentState.Version = $Object1.AppInstaller.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'appx'
  InstallerUrl  = $Object1.AppInstaller.MainBundle.Uri
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
