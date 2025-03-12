$Object1 = Invoke-WebRequest -Uri 'https://www.zultys.com/zac-download/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = [regex]::Match($Object1.Content, 'https://.+?ZAC_x86.+?\.exe').Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl = [regex]::Match($Object1.Content, 'https://.+?ZAC_x64.+?\.exe').Value
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $WinGetInstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'ZAC.msi'
      # AppsAndFeaturesEntries + ProductCode
      $Installer.AppsAndFeaturesEntries = @(
        [ordered]@{
          ProductCode   = $Installer.ProductCode = $InstallerFile2 | Read-ProductCodeFromMsi
          UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
          InstallerType = 'msi'
        }
      )
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
