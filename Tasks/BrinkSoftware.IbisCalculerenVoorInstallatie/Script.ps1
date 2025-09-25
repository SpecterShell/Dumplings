$InstallerLink = $Global:DumplingsStorage.BrinkSoftwareDownloadPage.Links.Where({ try { $_.href.Contains('.exe') -and $_.href.Contains('IbisCalculerenVoorInstallatie') -and $_.href.Contains('x64') } catch {} }, 'Last')[0]

# Version
$this.CurrentState.Version = [regex]::Match($InstallerLink.OuterHtml, '(\d+(?:\.\d+){2,})').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerLink.href | ConvertTo-UnescapedUri | Split-Uri -LeftPart Path
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'Ibis Calculeren voor Installatietechniek.msi'
      # ProductCode
      $Installer['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
      # AppsAndFeaturesEntries
      $Installer['AppsAndFeaturesEntries'] = @(
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
