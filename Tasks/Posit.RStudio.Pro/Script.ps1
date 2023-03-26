$Object1 = (Invoke-RestMethod -Uri 'https://www.rstudio.com/wp-content/downloads.json').rstudio.pro.stable.desktop.installer.windows

# Version
$Task.CurrentState.Version = $Object1.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.last_modified | Get-Date -Format 'yyyy-MM-dd'

# TODO: Implement modifications on Documentations
$Task.Config.Notes = "https://docs.posit.co/ide/desktop-pro/$($Task.CurrentState.Version)/"

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $ReleaseNotesUrl = 'https://docs.posit.co/ide/news/'
    $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@id='quarto-document-content']/section[contains(@id, '$($Task.CurrentState.Version.Split('+')[0])')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./blockquote[1]/following-sibling::*') | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl + '#' + $ReleaseNotesTitleNode.Attributes['id'].Value
        }
      } else {
        # ReleaseNotesUrl
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl
        }

        Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
