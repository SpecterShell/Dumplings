$Object1 = Invoke-RestMethod -Uri 'https://static.colomovers.com/win/strongvpn-appcast.xml'

# Version
$this.CurrentState.Version = $Object1[-1].enclosure.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1[-1].enclosure.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1[-1].pubDate | Get-Date -AsUTC

      $ReleaseNotesObject = $Object1[-1].description.'#cdata-section' | ConvertFrom-Html
      # Remove title
      $ReleaseNotesObject.SelectSingleNode('/h2[1]').Remove()
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
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
