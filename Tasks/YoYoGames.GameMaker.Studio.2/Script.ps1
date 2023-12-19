$Object = Invoke-RestMethod -Uri 'https://gms.yoyogames.com/update-win.rss'

# Version
$this.CurrentState.Version = [regex]::Match($Object[-1].title, 'Version ([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object[-1].enclosure.url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object[-1].pubDate | Get-Date -AsUTC

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object[-1].description | ConvertFrom-Html | Get-TextContent | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
