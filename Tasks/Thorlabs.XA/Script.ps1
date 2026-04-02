# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'XA Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'XA 32-Bit Software for 32-Bit Windows' }, 'First')[0].contentLink.expanded[0].download.url.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
}
$VersionX86 = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'XA Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'XA 32-Bit Software for 32-Bit Windows' }, 'First')[0].contentLink.expanded[0].version

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'XA Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'XA 64-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].download.url.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
}
$VersionX64 = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'XA Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'XA 64-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].version

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # LicenseUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'LicenseUrl'
        Value  = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'XA Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'XA 64-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].license.url.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'XA Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'XA 64-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].changeLog.url.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'Thorlabs XA*.msi' | Get-Item -Force | Select-Object -First 1
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
