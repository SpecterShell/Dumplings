$Object1 = Invoke-RestMethod -Uri 'https://cdn07.boxcdn.net/BoxForOfficeAutoupdate3.json'

# Version
$this.CurrentState.Version = $Object1.versions.default.version_name

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $Object1.versions.default.download_url
  ProductCode          = "Box for Office $($this.CurrentState.Version)"
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = $Object1.versions.default.custom_metadata.install_executable
    }
  )
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
