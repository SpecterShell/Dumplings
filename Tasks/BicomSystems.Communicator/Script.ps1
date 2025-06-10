# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = $Global:DumplingsStorage.BicomSystemsDownloadPage.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('Communicator') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($ReleaseNotesUrlLink = $Global:DumplingsStorage.BicomSystemsDownloadPage.Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('Communicator') -and $_.href -match 'Changelog' } catch {} }, 'First')) {
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
