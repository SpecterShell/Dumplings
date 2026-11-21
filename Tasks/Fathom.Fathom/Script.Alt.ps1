# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://electron-update.fathom.video/download/exe'
}

# Version
$this.CurrentState.Version = [regex]::Match((Get-RedirectedUrl1st -Uri $this.CurrentState.Installer[0].InstallerUrl -Method GET), '(\d+(?:\.\d+)+)').Groups[1].Value

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
