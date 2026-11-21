$Object1 = Invoke-RestMethod -Uri 'https://downloads.eligian.com/piicrawler-versions.json'

# Version
$this.CurrentState.Version = $Object1.win_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://downloads.eligian.com/PIICrawler-signed.msi'
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
