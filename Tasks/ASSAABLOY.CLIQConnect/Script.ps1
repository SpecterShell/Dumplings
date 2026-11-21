$Prefix = 'https://cliqconnect.assaabloy.com/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}updates.xml"
# windows-x64
$Object2 = $Object1.updateDescriptor.entry.Where({ $_.fileName.StartsWith('CLIQ_Connect_windows-x64') }, 'First')[0]

# Version
$this.CurrentState.Version = $Object2.newVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $Object2.fileName
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
