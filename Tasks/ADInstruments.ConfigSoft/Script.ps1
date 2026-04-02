$Object1 = Invoke-WebRequest -Uri 'https://www.adinstruments.com/support/downloads/windows/configsoft' -UserAgent $DumplingsBrowserUserAgent

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri $Object1.Links.Where({ try { $_.href.EndsWith('.zip') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe x -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'ConfigSoft 32bit\setup.exe' 'ConfigSoft 64bit\setup.exe' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'ConfigSoft 32bit\setup.exe'
    $InstallerFile2Extracted = $InstallerFile2 | Expand-InstallShield
    $InstallerFile3 = Join-Path $InstallerFile2Extracted 'ConfigSoft.msi'
    # ProductCode
    $InstallerX86['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $InstallerX86['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
    $InstallerFile4 = Join-Path $InstallerFileExtracted 'ConfigSoft 64bit\setup.exe'
    $InstallerFile4Extracted = $InstallerFile4 | Expand-InstallShield
    $InstallerFile5 = Join-Path $InstallerFile4Extracted 'ConfigSoft.msi'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile5 | Read-ProductVersionFromMsi
    # ProductCode
    $InstallerX64['ProductCode'] = $InstallerFile5 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        UpgradeCode   = $InstallerFile5 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
    Remove-Item -Path $InstallerFile4Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    Remove-Item -Path $InstallerFile2Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
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
