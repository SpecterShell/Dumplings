$Object1 = Invoke-WebRequest -Uri 'https://www.defenderui.com/download/duiversion.txt'

# Version
$this.CurrentState.Version = $Object1.Content.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.defenderui.com/Download/InstallDefenderUI.exe'
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
