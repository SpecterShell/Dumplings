$Object1 = Invoke-WebRequest -Uri 'https://zoom.bimcollab.com/Downloads/UpdatesConfigurationFile.txt' | Read-ResponseContent -Encoding 'windows-1252' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.BIMcollabInstaller.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.BIMcollabInstaller.URL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    $InstallerFileExtracted = New-TempFolder
    Start-Process -FilePath $InstallerFile -ArgumentList @('/extract', $InstallerFileExtracted) -Wait
    $InstallerFile2 = Get-ChildItem -Path $InstallerFileExtracted -Include '*.msi' -Recurse | Select-Object -First 1
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
    # ProductCode
    $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

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
