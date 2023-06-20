$Object = Invoke-RestMethod -Uri 'https://gms.yoyogames.com/update-win.rss'

# Version
$Task.CurrentState.Version = [regex]::Match($Object[-1].title, 'Version ([\d\.]+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object[-1].enclosure.url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object[-1].pubDate | Get-Date -AsUTC

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object[-1].description | ConvertFrom-Html | Get-TextContent | Format-Text
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
