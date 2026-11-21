# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = Get-RedirectedUrl1st -Uri 'https://clientdownload.catonetworks.com/public/clients/CatoBrowser.exe'
}
# Version
$this.CurrentState.Version = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

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
