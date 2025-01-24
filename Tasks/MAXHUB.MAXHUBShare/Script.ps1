# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://ota.ifpserver.com/resources/maxhub-share?agent=d'
}

# Version
$this.CurrentState.Version = [regex]::Match((Get-RedirectedUrl -Uri $this.CurrentState.Installer[0].InstallerUrl), '(\d+\.\d+\.\d+\.\d+_\d+)').Groups[1].Value

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
