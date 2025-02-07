$Object1 = Invoke-RestMethod -Uri 'https://www.pgadmin.org/versions.json'

# Version
$this.CurrentState.Version = $Object1.pgadmin4.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://ftp.postgresql.org/pub/pgadmin/pgadmin4/v$($this.CurrentState.Version)/windows/pgadmin4-$($this.CurrentState.Version)-x64.exe"
  ProductCode  = "pgAdmin 4v$($this.CurrentState.Version.Split('.')[0])_is1"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # ReleaseNotesUrl
    $this.CurrentState.Locale += [ordered]@{
      Key   = 'ReleaseNotesUrl'
      Value = 'https://www.pgadmin.org/news/'
    }

    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://www.pgadmin.org/news.rss').Where({ $_.title.Contains('pgAdmin 4') -and $_.title.Contains("v$($this.CurrentState.Version)") }, 'First')

      if ($Object2) {
        $ReleaseNotesObject = $Object2[0].description | ConvertFrom-Html
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and -not $Node.InnerText.Contains('your copy now'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object2[0].link
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $ReleaseNotesUrl = "https://www.pgadmin.org/docs/pgadmin4/$($this.CurrentState.Version)/release_notes_$($this.CurrentState.Version.Replace('.', '_')).html"
      Invoke-WebRequest -Uri $ReleaseNotesUrl -Method Head | Out-Null

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl
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
