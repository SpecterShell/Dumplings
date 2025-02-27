$Object1 = Invoke-RestMethod -Uri 'https://www.heidisql.com/updatecheck.php?bits=64' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.Release.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Release.URL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.Release.Date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://www.heidisql.com/rss.php?c=1,7').Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object2) {
        $ReleaseNotesObject = $Object2[0].content.'#text' | ConvertFrom-Html
        # Remove the download link
        $ReleaseNotesObject.SelectNodes('/p[contains(./a/@href, "download.php")]').ForEach({ $_.Remove() })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object2[0].link.href
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
