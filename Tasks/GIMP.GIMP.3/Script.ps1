$Object1 = ((Invoke-WebRequest -Uri 'https://www.gimp.org/gimp_versions.json').Content | ConvertFrom-Json -AsHashtable).STABLE.Where({ $_.version.StartsWith('3.') }, 'First')[0]

# Version
$this.CurrentState.Version = "$($Object1.version).$($Object1.windows[0].Contains('revision') ? $Object1.windows[0].revision : '0')"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri "https://download.gimp.org/gimp/v$($this.CurrentState.Version.Split('.')[0..1] -join '.')/windows/" $Object1.windows[0].filename
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesUrl = "https://www.gimp.org/release-notes/gimp-$($this.CurrentState.Version.Split('.')[0..1] -join '.').html"
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
      }

      # Remove header links
      $Object2.SelectNodes('//a[@class="headerlink"]').ForEach({ $_.Remove() })
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectSingleNode('//section[@class="page_content"]') | Get-TextContent | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.windows[0].date | Get-Date -Format 'yyyy-MM-dd'

      if ($Object1.windows[0].Contains('comment')) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object1.windows[0].comment | Format-Text
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
