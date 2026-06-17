# x86
$Object1 = $Global:DumplingsStorage.TrackerSoftwareApps.UpdaterData.bundle.Where({ $_.id -eq 'Pro.x32' }, 'First')[0].update[-1]
$VersionX86 = $Object1.version

# x64
$Object2 = $Global:DumplingsStorage.TrackerSoftwareApps.UpdaterData.bundle.Where({ $_.id -eq 'Pro.x64' }, 'First')[0].update[-1]
$VersionX64 = $Object2.version

# arm64
$Object3 = $Global:DumplingsStorage.TrackerSoftwareApps.UpdaterData.bundle.Where({ $_.id -eq 'Pro.arm64' }, 'First')[0].update[-1]
$VersionARM64 = $Object3.version

if (@(@($VersionX86, $VersionX64, $VersionARM64) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}, arm64 version: ${VersionARM64}", 'Error')
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
  InstallerUrl  = Join-Uri "https://downloads.pdf-xchange.com/$($this.CurrentState.Version)/" $Object3.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'https://www.pdf-xchange.com/product/pdf-xchange-pro/history'
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      if ($ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(., '$($this.CurrentState.Version)')]")) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p[contains(@class, "maintenance")]/span[contains(@class, "release-date-value")]').InnerText, '([a-zA-Z]+\W+\d{1,2}[a-zA-Z]+\W+20\d{2})').Groups[1].Value,
          [string[]]@(
            "MMM d'st', yyyy"
            "MMM d'nd', yyyy"
            "MMM d'rd', yyyy"
            "MMM d'th', yyyy"
          ),
          (Get-Culture -Name 'en-US'),
          [System.Globalization.DateTimeStyles]::None
        ).ToString('yyyy-MM-dd')

        # Remove list prefix
        $Object2.SelectNodes('//i[contains(@class, "icon")]').ForEach({ $_.Remove() })

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::div[contains(@class, "bh-items")]') | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = "${ReleaseNotesUrl}?build=$($this.CurrentState.Version)"
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
