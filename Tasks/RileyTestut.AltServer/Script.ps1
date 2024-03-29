$Object1 = Invoke-RestMethod -Uri 'https://altstore.io/altserver/sparkle-windows.xml'

# Version
$this.CurrentState.Version = $Object1[0].enclosure.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1[0].enclosure.url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1[0].pubDate | Get-Date -AsUTC

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1[0].description.'#cdata-section' | ConvertFrom-Html | Get-TextContent | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # RealVersion
    $this.CurrentState.RealVersion = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromMsi

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
