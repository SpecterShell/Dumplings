$Object1 = Invoke-RestMethod -Uri 'https://api.meetsidekick.com/installer/browser/win'

# Version
$this.CurrentState.Version = $Object1.browser_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.browser_url
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
