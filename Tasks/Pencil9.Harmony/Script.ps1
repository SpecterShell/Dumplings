$Prefix = 'https://www.pencil9.com/harmony-download.html'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href -match 'Harmony_(\d+(_\d+)+)\.msi$' } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = $Matches[1] -replace '_', '.'

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
