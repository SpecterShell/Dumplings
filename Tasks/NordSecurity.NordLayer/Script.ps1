$Object1 = (Invoke-WebRequest -Uri 'https://downloads.nordlayer.com/win/latest/update.xml' | Read-ResponseContent | ConvertFrom-Xml).channels.channel.Where({ $_.name -notin @('staging', 'updates', 'test') }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.releases.release.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.releases.release.update.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    $InstallerFileExtracted = New-TempFolder
    Start-Process -FilePath $InstallerFile -ArgumentList @('/extract', $InstallerFileExtracted) -Wait
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'NordLayerSetup.msi'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
    # AppsAndFeaturesEntries + ProductCode
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )

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
