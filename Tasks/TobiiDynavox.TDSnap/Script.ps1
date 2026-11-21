# The CDN pads the response with trailing whitespace, which breaks the XmlDocument conversion inside Get-AppInstallerInfo.
$Object1 = Get-AppInstallerInfo -Content ((Invoke-WebRequest -Uri 'https://download.mytobiidynavox.com/Snap/installers/td-distribute/Snap.WindowsUWP.OEM.appinstaller' | Read-ResponseContent).Trim())

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = $Object1.InstallerType
  InstallerUrl  = $Object1.InstallerUrl | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = $Object1.InstallerType
  InstallerUrl  = $Object1.InstallerUrl | ConvertTo-UnescapedUri
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
