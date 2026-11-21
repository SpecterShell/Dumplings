$Object1 = Invoke-RestMethod -Uri 'https://tenzen.studio/api/v1/photon/releases/latest'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = "https://downloads.tenzen.studio/photon/stable/win32/$($this.CurrentState.Version)/Photon-Studio-$($this.CurrentState.Version)-win-x64.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'nullsoft'
  InstallerUrl  = "https://downloads.tenzen.studio/photon/stable/win32/$($this.CurrentState.Version)/Photon-Studio-$($this.CurrentState.Version)-win-arm64.exe"
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
