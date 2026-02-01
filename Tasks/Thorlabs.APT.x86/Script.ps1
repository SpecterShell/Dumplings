# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'Archive' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -like 'APT * 32-Bit Software for 32-Bit Windows' }, 'First')[0].contentLink.expanded[0].download.url.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'Archive' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -like 'APT * 32-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].download.url.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
}

# Version
$this.CurrentState.Version = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'Archive' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -like 'APT * 32-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].version

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'Archive' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -like 'APT * 32-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'Thorlabs APT*.msi' | Get-Item -Force | Select-Object -First 1
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

      $ReleaseNotesUrl = $Global:DumplingsStorage.KinesisDownloadPage.tabs.Where({ $_.contentLink.expanded.name -eq 'Archive' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -like 'APT * 32-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].changeLog.url.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri $ReleaseNotesUrl).RawContentStream)

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
      }

      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String -match "^APT V$([regex]::Escape($this.CurrentState.Version))") {
          if ($String -match '(\d{1,2}/[a-zA-Z]+/20\d{2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
          } else {
            $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          }
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if (-not $String.Contains('Device Firmware')) {
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
