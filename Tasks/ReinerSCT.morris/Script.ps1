$Object1 = Invoke-RestMethod -Uri 'https://dp.reiner-sct.com/morris/versions.dat'

# Version
$this.CurrentState.Version = $Object1.application.morris.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://dp.reiner-sct.com/downloads/d.php?s=mo&f=morris_V_$($this.CurrentState.Version.Replace('.', '_')).exe"
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
