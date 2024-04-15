$Object1 = Invoke-RestMethod -Uri 'https://versionhistory.googleapis.com/v1/chrome/platforms/win/channels/beta/versions'

# Version
$this.CurrentState.Version = $Object1.versions[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://dl.google.com/dl/chrome/install/beta/googlechromebetastandaloneenterprise.msi'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://dl.google.com/dl/chrome/install/beta/googlechromebetastandaloneenterprise64.msi'
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
