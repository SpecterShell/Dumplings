# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = $InstallerUrlEXE = $Global:DumplingsStorage.BicomSystemsDownloadPage.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('gloCOM') } catch {} }, 'First')[0].href
}
$VersionEXE = [regex]::Match($InstallerUrlEXE, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msix'
  InstallerUrl  = $InstallerUrlMSIX = $Global:DumplingsStorage.BicomSystemsDownloadPage.Links.Where({ try { $_.href.EndsWith('.msix') -and $_.href.Contains('gloCOM') } catch {} }, 'First')[0].href
}
$VersionMSIX = [regex]::Match($InstallerUrlMSIX, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionEXE -ne $VersionMSIX) {
  $this.Log("EXE version: ${VersionEXE}")
  $this.Log("MSIX version: ${VersionMSIX}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionEXE

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($ReleaseNotesUrlLink = $Global:DumplingsStorage.BicomSystemsDownloadPage.Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('gloCOM') -and $_.href -match 'Changelog' } catch {} }, 'First')) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrlLink[0].href
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
