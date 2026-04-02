$Object1 = Invoke-RestMethod -Uri 'https://polleverywhere-app.s3.amazonaws.com/win-stable/appcast.xml'

# Version
$this.CurrentState.Version = $Object1.enclosure.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Object1.enclosure.url.Replace('//s3.amazonaws.com/polleverywhere-app/', '//polleverywhere-app.s3.amazonaws.com/') 'PollEverywhere.Everyone.msi'
  # InstallerUrl = Join-Uri $Object1.enclosure.url.Replace('//s3.amazonaws.com/polleverywhere-app/', '//polleverywhere-app.s3.amazonaws.com/') 'PollEverywhere.PowerPointAddInSetup.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.pubDate | Get-Date -AsUTC

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Object1.releaseNotesLink
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
  'Changed| Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
