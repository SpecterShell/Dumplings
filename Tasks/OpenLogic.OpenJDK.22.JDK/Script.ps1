$Object1 = $Global:DumplingsStorage.OpenLogicBuilds.Where({ $_.Package -eq 'openlogic-openjdk' -and $_.Version.StartsWith('22.') }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.Version -replace '\+', '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = $Object1.Arch
  InstallerUrl = $Object1.Url
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
