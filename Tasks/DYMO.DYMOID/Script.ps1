$Object1 = Invoke-RestMethod -Uri 'https://download.dymo.com/dymo/Software/DYMO%20ID/swupdate/DZUpdate.en.xml'

# Version
$this.CurrentState.Version = $Object1.dz_updates.desktop_sw_update.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.dz_updates.desktop_sw_update.download_url | ConvertTo-UnescapedUri | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'DYMO ID.msi'
      # ProductCode
      $Installer.ProductCode = $InstallerFile2 | Read-ProductCodeFromMsi
      # AppsAndFeaturesEntries
      $Installer.AppsAndFeaturesEntries = @(
        [ordered]@{
          UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
          InstallerType = 'msi'
        }
      )
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    }

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
