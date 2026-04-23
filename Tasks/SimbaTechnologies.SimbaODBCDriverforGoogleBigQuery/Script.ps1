$Object1 = Invoke-WebRequest -Uri 'https://docs.cloud.google.com/bigquery/docs/reference/odbc-jdbc-drivers'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href -match 'SimbaODBCDriverforGoogleBigQuery32' } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href -match 'SimbaODBCDriverforGoogleBigQuery64' } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.txt') -and $_.href -match 'release-notes' } catch {} }, 'First')[0].href

      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri $ReleaseNotesUrl).RawContentStream)

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
      }

      while (-not $Object2.EndOfStream) {
        if ($Object2.ReadLine() -match "^$([regex]::Escape($this.CurrentState.Version))") {
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if ($String -match '^Release (20\d{2}-\d{1,2}-\d{1,2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
          } elseif ($String -notmatch '(-|=){3,}$') {
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
