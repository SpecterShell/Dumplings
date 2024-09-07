$Object1 = (Invoke-RestMethod -Uri 'https://jidusm.wlhex.com/pcversion.text').ToString()

# Version
$this.CurrentState.Version = $Object1

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://download.wlhex.com/oss.php?fileName=jidusm$($this.CurrentState.Version)x86Setup.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://download.wlhex.com/oss.php?fileName=jidusm$($this.CurrentState.Version)x64Setup.exe"
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
