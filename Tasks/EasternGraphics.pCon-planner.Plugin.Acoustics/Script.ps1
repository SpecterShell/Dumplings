$Object1 = Invoke-RestMethod -Uri 'https://download-center.pcon-solutions.com/index.php?rest_route=/wp/v2/posts/1082'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.title.rendered, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://downloads.pcon-solutions.com/pCon/plannerPlugins/Acoustics/$($this.CurrentState.Version)/X3G-Acoustics_$($this.CurrentState.Version)_setup.zip"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://docs.pcon-solutions.com/pCon/plannerPlugins/Acoustics/$($this.CurrentState.Version)/X3G-Acoustics_Sales-Features_$($this.CurrentState.Version.Split('.')[0..1] -join '.')_en.pdf"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = New-TempFolder
      7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'pCon.planner_Plugin_Acoustics.exe' | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'pCon.planner_Plugin_Acoustics.exe'
      $InstallerFile2Extracted = $InstallerFile2 | Expand-InstallShield
      $InstallerFile3 = Join-Path $InstallerFile2Extracted 'pCon.planner Plugin - Acoustics.msi'
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
