$Object1 = Invoke-RestMethod -Uri 'https://accoblobstorageus.blob.core.windows.net/software/version/konnect/knt_win.json'

# Version
$this.CurrentState.Version = "$($Object1.version_major).$($Object1.version_minor).$($Object1.version_build)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_date.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Prefix = 'https://www.kensington.com/software/kensington-konnect/'
      }

      $Object2 = Invoke-WebRequest -Uri $Prefix

      $ReleaseNotesUrlLink = $Object2.Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('truehue') -and $_.href.Contains('release-note') } catch {} }, 'First')
      if ($ReleaseNotesUrlLink) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = Join-Uri $Prefix $ReleaseNotesUrlLink[0].href
        }
      } else {
        $this.Log("No ReleaseNotesUrl (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
