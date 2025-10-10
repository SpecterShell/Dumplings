$Object1 = Invoke-RestMethod -Uri 'https://builds.balsamiq.com/bwd/win.jsonp' | Get-EmbeddedJson -StartsFrom 'jsoncallback(' | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'inno'
  InstallerUrl  = "https://build_archives.s3.amazonaws.com/Wireframes-Windows/Balsamiq_Wireframes_$($this.CurrentState.Version)_x86_Setup.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = "https://build_archives.s3.amazonaws.com/Wireframes-Windows/Balsamiq_Wireframes_$($this.CurrentState.Version)_x64_Setup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://balsamiq.com/wireframes/desktop/release-notes/#win'
      }

      $Object2 = (Invoke-RestMethod -Uri 'https://balsamiq.com/product/desktop/release-notes.rss').Where({ $_.encoded.'#cdata-section' -match "Windows: $([regex]::Escape($this.CurrentState.Version))" }, 'First')

      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= $Object2[0].lastBuildDate | Get-Date -AsUTC

        # ReleaseNotes (en-US)
        $ReleaseNotesObject = $Object2[0].encoded.'#cdata-section' | ConvertFrom-Html
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject.SelectNodes('/hr[1]/following-sibling::node()') | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $Object2[0].link
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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

    if ($this.Status.Contains('New') -and ($this.LastState.Version.Split('.')[0..1] -join '.') -ne ($this.CurrentState.Version.Split('.')[0..1] -join '.')) {
      $this.Log('Major or minor version number has changed, please update the old installer URLs.', 'Warning')
    }
  }
}
