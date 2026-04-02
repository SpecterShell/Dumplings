$Object1 = Invoke-RestMethod -Uri 'https://updates.i3sw.i3-technologies.com/i3allsync4/transmitter/windows/windows_install.xml'

# Version
$this.CurrentState.Version = $Object1.enclosure.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.enclosure.url -replace '\.exe$', '.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.pubDate | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Object1.releaseNotesLink.Trim()
      }

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html | Get-TextContent | Format-Text
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
