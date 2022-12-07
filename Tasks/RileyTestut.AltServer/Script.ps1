$Object = Invoke-RestMethod -Uri 'https://altstore.io/altserver/sparkle-windows.xml'

# Version
$Task.CurrentState.Version = $Object[0].enclosure.version

# Installer
$InstallerUrl = $Object[0].enclosure.url
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object[0].pubDate | Get-Date -AsUTC

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object[0].description.'#cdata-section' | ConvertFrom-Html | Get-TextContent | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
