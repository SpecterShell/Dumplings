$Object1 = $Global:DumplingsStorage.ElgatoApps.downloadData.'wave-link-3-win'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.fileURLs.x86_64
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object1.fileURLs.arm64
}

# Version
$this.CurrentState.Version = [regex]::Matches($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)')[-1].Groups[1].Value

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
