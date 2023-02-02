$Object = Invoke-RestMethod -Uri 'https://altstore.io/altserver/sparkle-windows.xml'

# Version
$Task.CurrentState.Version = $Object[0].enclosure.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object[0].enclosure.url
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
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromMsi

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
