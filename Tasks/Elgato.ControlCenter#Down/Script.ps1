$Object1 = $Global:DumplingsStorage.ElgatoApps.downloadData.'cc-win'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.downloadURL
}

# Version
$this.CurrentState.Version = [regex]::Matches($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)')[-1].Groups[1].Value

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
