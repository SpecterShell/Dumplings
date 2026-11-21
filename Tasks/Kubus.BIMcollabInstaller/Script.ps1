$Object1 = Invoke-WebRequest -Uri 'https://zoom.bimcollab.com/Downloads/UpdatesConfigurationFile.txt' | Read-ResponseContent -Encoding 'windows-1252' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.BIMcollabInstaller.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.BIMcollabInstaller.URL -replace '\.exe$', '.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
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
