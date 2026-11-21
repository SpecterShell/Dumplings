$Object1 = Invoke-RestMethod -Uri 'https://dwversion.openmolecules.org/?what=properties' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1._.manual_update_version -replace '^v' -replace '0+(?!\.|$)'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://openmolecules.org/datawarrior/datawarrior$($this.CurrentState.Version.Replace('.', '')).msi"
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
