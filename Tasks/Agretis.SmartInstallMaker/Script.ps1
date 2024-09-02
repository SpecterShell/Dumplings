$Object1 = Invoke-RestMethod -Uri 'http://www.sminstall.com/update.txt' | Split-LineEndings

# Version
$this.CurrentState.Version = $Object1[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1[1]
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
