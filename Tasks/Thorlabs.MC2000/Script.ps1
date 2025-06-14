$Prefix = 'https://www.thorlabs.com/software_pages/ViewSoftwarePage.cfm?Code=MC2000'

$Object1 = Invoke-WebRequest -Uri $Prefix
$Object2 = $Object1 | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match($Object2.SelectSingleNode('//tr[contains(./td[1], "Version")]/td[2]').InnerText, '(\d+(\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.zip') } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = New-TempFolder
      7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'setup.exe' | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'setup.exe'
      $InstallerFile2Extracted = $InstallerFile2 | Expand-InstallShield
      $InstallerFile3 = Join-Path $InstallerFile2Extracted 'MC2000.msi'
      # RealVersion
      $this.CurrentState.RealVersion = $InstallerFile3 | Read-ProductVersionFromMsi
      # ProductCode
      $Installer['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
      # AppsAndFeaturesEntries
      $Installer['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
          InstallerType = 'msi'
        }
      )
      Remove-Item -Path $InstallerFile2Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
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
