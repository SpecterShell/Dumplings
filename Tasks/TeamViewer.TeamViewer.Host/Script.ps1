$Object1 = Invoke-WebRequest -Uri 'https://download.teamviewer.com/download/update/TVHVersion15.txt'
# $Object1 = Invoke-WebRequest -Uri 'https://download.teamviewer.com/download/update/TVHMSIVersion15.txt'

# Version
$this.CurrentState.Version = $Object1.Content.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'nullsoft'
  InstallerUrl  = "https://download.teamviewer.com/download/version_$($this.CurrentState.Version.Split('.')[0])x/TeamViewer_Host_Setup.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = "https://download.teamviewer.com/download/version_$($this.CurrentState.Version.Split('.')[0])x/TeamViewer_Host_Setup_x64.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x86'
  InstallerType       = 'zip'
  NestedInstallerType = 'wix'
  InstallerUrl        = "https://download.teamviewer.com/download/version_$($this.CurrentState.Version.Split('.')[0])x/update/Update_msi_Host_$($this.CurrentState.Version).zip"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'wix'
  InstallerUrl        = "https://download.teamviewer.com/download/version_$($this.CurrentState.Version.Split('.')[0])x/update/Update_msi_Host_$($this.CurrentState.Version)_x64.zip"
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
