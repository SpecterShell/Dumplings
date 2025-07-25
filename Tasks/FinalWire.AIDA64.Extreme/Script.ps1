$Object1 = Invoke-RestMethod -Uri 'https://update.aida64.com/update/' -Body @{
  pt = 'a64xe'
  pb = $this.Status.Contains('New') ? '7.70.7500' : $this.LastState.Version
  pi = 'exe'
  pl = 'en'
  ov = '0'
  cp = '0'
}

# Version
$this.CurrentState.Version = $Object1.aida64.releasepack[-1].version

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..1] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.aida64.com/aida64extreme$($this.CurrentState.Version.Split('.')[0..1] -join '').exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.aida64.releasepack[-1].rdate | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.aida64.releasepack[-1].wnew.item | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'https://www.aida64.com/news'
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl

      if ($ReleaseNotesUrlLink = $Object2.Links.Where({ try { $_.outerHTML.Contains("v$($this.CurrentState.Version.Split('.')[0..1] -join '.')") } catch {} }, 'First')) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = Join-Uri $ReleaseNotesUrl $ReleaseNotesUrlLink[0].href
        }
      } else {
        $this.Log("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
