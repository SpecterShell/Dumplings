$Object1 = (Invoke-WebRequest -Uri 'https://downloads.nordlayer.com/win/latest/update.xml' | Read-ResponseContent | ConvertFrom-Xml).channels.channel.Where({ $_.name -notin @('staging', 'updates', 'test') }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.releases.release.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.releases.release.update.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    $NestedInstallerFileRoot = New-TempFolder
    Start-Process -FilePath $InstallerFile -ArgumentList @('/extract', $NestedInstallerFileRoot) -Wait
    $NestedInstallerFile = Join-Path $NestedInstallerFileRoot 'NordLayerSetup.msi'

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $NestedInstallerFile | Read-ProductVersionFromMsi
    # AppsAndFeaturesEntries + ProductCode
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $this.CurrentState.Installer[0]['ProductCode'] = $NestedInstallerFile | Read-ProductCodeFromMsi
        UpgradeCode   = $NestedInstallerFile | Read-UpgradeCodeFromMsi
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
