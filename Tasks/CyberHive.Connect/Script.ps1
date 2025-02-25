$Object1 = Invoke-RestMethod -Uri 'https://pkgs.cyberhive.com/windows/connect-win.xml'

# Version
$this.CurrentState.Version = $Object1.version

$Object2 = Invoke-WebRequest -Uri $Object1.link

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains($this.CurrentState.Version) } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.pubDate | Get-Date -AsUTC

      # ReleaseNotes
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.description.'#cdata-section' | ConvertFrom-Html | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.link
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
