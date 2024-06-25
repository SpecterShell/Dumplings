$Object1 = $Global:DumplingsStorage.VisualStudioManifest.packages.Where({ $_.id -eq 'Microsoft.VisualCpp.Redist.14' -and $_.chip -eq 'x64' }, 'First')[0]

# Version
$this.CurrentState.Version = "$($Object1.version).0"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.payloads.Where({ $_.fileName -eq 'VC_redist.x64.exe' }, 'First')[0].url
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
