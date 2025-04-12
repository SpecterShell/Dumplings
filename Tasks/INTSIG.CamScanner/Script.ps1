# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl1st -Uri 'https://cc.co/16YS3k'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $this.CurrentState.Installer[0].InstallerUrl.Replace('x64', 'x32')
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'CamScanner-(\d+(?:\.\d+)+)').Groups[1].Value

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
