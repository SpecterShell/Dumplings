$Object1 = (Invoke-RestMethod -Uri 'https://downloads.druva.com/insync/js/data.json').Where({ $_.title -eq 'Windows' }, 'First')[0].installerDetails[0]

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.downloadURL
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
