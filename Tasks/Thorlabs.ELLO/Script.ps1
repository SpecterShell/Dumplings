$Prefix = 'https://www.thorlabs.com/software_pages/ViewSoftwarePage.cfm?Code=ELL'

$Object1 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('x86') } catch {} }, 'First')[0].href
}
$VersionX86 = [regex]::Match($InstallerUrlX86, '(\d+(\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('x64') } catch {} }, 'First')[0].href
}
$VersionX64 = [regex]::Match($InstallerUrlX64, '(\d+(\.\d+)+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'Thorlabs ELLO.msi'
      # RealVersion
      $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
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
