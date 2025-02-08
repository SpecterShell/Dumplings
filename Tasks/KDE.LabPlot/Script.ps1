$Object1 = Invoke-WebRequest -Uri 'https://labplot.org/download/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('x86_64') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://labplot.org/news/'
      }

      $Object2 = (Invoke-RestMethod -Uri 'https://labplot.org/feed/').Where({ $_.title.Contains($this.CurrentState.Version.Split('.')[0..1] -join '.') }, 'First')

      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object2[0].pubDate | Get-Date -AsUTC

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].encoded.'#cdata-section' | ConvertFrom-Html | Get-TextContent | Format-Text
        }
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object2[0].link
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      foreach ($Installer in $this.CurrentState.Installer) {
        # InstallerSha256
        $Installer['InstallerSha256'] = (Invoke-RestMethod -Uri "$($Installer.InstallerUrl).sha256").Split()[0].ToUpper()
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
