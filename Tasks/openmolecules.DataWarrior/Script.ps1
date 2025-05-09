$Prefix = 'https://openmolecules.org/datawarrior/download.html'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'DataWarrior V(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.msi') } catch {} }, 'First')[0].href
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
