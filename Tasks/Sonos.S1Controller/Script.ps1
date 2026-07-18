# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-WinGetDeliveryOptimizationRedirectedUrl -Uri 'https://www.sonos.com/redir/controller_software_pc'
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+-\d+)').Groups[1].Value.Replace('-', '.')

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
