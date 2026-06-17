# x86
$Object1 = $Global:DumplingsStorage.TrackerSoftwareApps.UpdaterData.bundle.Where({ $_.id -eq 'DriverStd.x32' }, 'First')[0].update[-1]
$VersionX86 = $Object1.version

# x64
$Object2 = $Global:DumplingsStorage.TrackerSoftwareApps.UpdaterData.bundle.Where({ $_.id -eq 'DriverStd.x64' }, 'First')[0].update[-1]
$VersionX64 = $Object2.version

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = Join-Uri "https://downloads.pdf-xchange.com/$($this.CurrentState.Version)/" $Object1.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = Join-Uri "https://downloads.pdf-xchange.com/$($this.CurrentState.Version)/" $Object2.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'wix'
  InstallerUrl  = "https://downloads.pdf-xchange.com/$($this.CurrentState.Version)/StandardV$($this.CurrentState.Version.Split('.')[0]).ARM64.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://www.pdf-xchange.com/product/pdf-xchange-standard/history'
      }

      $Object2 = Invoke-RestMethod -Uri 'https://www.pdf-xchange.com/build-history-feed/pdf-xchange-standard.xml'

      if ($ReleaseNotesObject = $Object2.Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesObject[0].pubDate | Get-Date -AsUTC

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject[0].description.'#cdata-section' | ConvertFrom-Html | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesObject[0].link
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
