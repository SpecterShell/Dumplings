$Object1 = Invoke-RestMethod -Uri 'http://redirect.audiocodes.com/install/configBuilder/info.txt'

# Version
$this.CurrentState.Version = [regex]::Match($Object1, 'VERSION (\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://tools.audiocodes.com/install/configBuilder/configBuilder-setup.exe'
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
