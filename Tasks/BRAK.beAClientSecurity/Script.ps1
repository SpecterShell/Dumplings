$Prefix = 'https://installer.bea-brak.de/cs/installation/1/'
$Object1 = Invoke-RestMethod -Uri "${Prefix}updates.xml"
$Object2 = $Object1.updateDescriptor.entry.Where({ $_.targetMediaFileId -eq '2224' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object2.newVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl    = Join-Uri $Prefix $Object2.fileName
  InstallerSha256 = $Object2.sha256Sum.ToUpper()
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
