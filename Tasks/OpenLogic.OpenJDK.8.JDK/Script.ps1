$Object1 = $Global:DumplingsStorage.OpenLogicBuilds.Where({ $_.Package -eq 'openlogic-openjdk' -and $_.Version.StartsWith('8u') })

# Version
$this.CurrentState.Version = $Object1[0].Version -replace '^8u', '8.0.' -replace '-b', '.'

# Installer
foreach ($Object2 in $Object1.Where({ $_.Version -eq $Object1[0].Version })) {
  $this.CurrentState.Installer += [ordered]@{
    Architecture = $Object2.Arch
    InstallerUrl = $Object2.Url
  }
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
