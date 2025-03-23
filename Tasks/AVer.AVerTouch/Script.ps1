$Object1 = Invoke-RestMethod -Uri 'http://download.aver.com/AVerTouchWindows/check4Update/update.cfg' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.OTA.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.OTA.Path
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.OTA.ReleaseDate | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = New-TempFolder
      7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'AVerTouchQt.exe' | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'AVerTouchQt.exe'
      $InstallerFile2Extracted = $InstallerFile2 | Expand-InstallShield
      $InstallerFile3 = Join-Path $InstallerFile2Extracted 'AVerTouch.msi'
      # AppsAndFeaturesEntries + ProductCode
      $Installer.AppsAndFeaturesEntries = @(
        [ordered]@{
          ProductCode   = $Installer.ProductCode = $InstallerFile3 | Read-ProductCodeFromMsi
          UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
          InstallerType = 'msi'
        }
      )
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
      Remove-Item -Path $InstallerFile2Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
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
