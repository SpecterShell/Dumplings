# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'XA Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'XA 32-Bit Software for 32-Bit Windows' }, 'First')[0].contentLink.expanded[0].download.url
}
$VersionX86 = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'XA Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'XA 32-Bit Software for 32-Bit Windows' }, 'First')[0].contentLink.expanded[0].version

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'XA Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'XA 64-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].download.url
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
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'XA Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'XA 64-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # LicenseUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'LicenseUrl'
        Value  = "https://www.thorlabs.com/Software/Motion Control/XA/V$($this.CurrentState.Version)/License Agreement.rtf"
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = "https://www.thorlabs.com/Software/Motion Control/XA/V$($this.CurrentState.Version)/ChangeLog.rtf"
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
