# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'Kinesis Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'Kinesis 32-Bit Software for 32-Bit Windows' }, 'First')[0].contentLink.expanded[0].download.url.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
}
$VersionX86 = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'Kinesis Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'Kinesis 32-Bit Software for 32-Bit Windows' }, 'First')[0].contentLink.expanded[0].version

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'Kinesis Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'Kinesis 32-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].download.url.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
}
$VersionX64 = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'Kinesis Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'Kinesis 32-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].version

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
      $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'Kinesis Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'Kinesis 32-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'Thorlabs Kinesis*.msi' | Get-Item -Force | Select-Object -First 1
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

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      $ReleaseNotesUrl = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'Kinesis Software' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'Kinesis 32-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].changeLog.url.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri $ReleaseNotesUrl).RawContentStream)

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
      }

      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String -match "^Version $([regex]::Escape($this.CurrentState.Version))") {
          if ($String -match '(\d{1,2}[a-zA-Z]+\W+[a-zA-Z]+\W+20\d{2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
              $Matches[1],
              [string[]]@(
                "d'st' MMMM yyyy",
                "d'nd' MMMM yyyy",
                "d'rd' MMMM yyyy",
                "d'th' MMMM yyyy"
              ),
              (Get-Culture -Name 'en-US'),
              [System.Globalization.DateTimeStyles]::None
            ).ToString('yyyy-MM-dd')
          } else {
            $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          }
          $null = $Object2.ReadLine()
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if ($String -notmatch '^Version \d+(\.\d+)+ ') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
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
