$Object1 = $Global:DumplingsStorage.MYOBApps.items.Where({ $_.fields.product -eq 'AccountRight MSI' -and -not $_.fields.version.Contains('AddOn Connector') }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($Object1.fields.version, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.fields.installerLink
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

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
