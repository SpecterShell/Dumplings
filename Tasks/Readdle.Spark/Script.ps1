$Object1 = Invoke-RestMethod -Uri 'https://downloads.sparkmailapp.com/Spark3/win/dist/appcast.xml'

# Version
$this.CurrentState.Version = $Object1.enclosure.version

# RealVersion
$this.CurrentState.RealVersion = [regex]::Match($this.CurrentState.Version, '^(\d+\.\d+\.\d+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.enclosure.url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.pubDate | Get-Date -AsUTC

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = Invoke-WebRequest -Uri $Object1.releaseNotesLink | ConvertFrom-Html

      if ($Object2.SelectSingleNode('/html/body/p[1]/strong').InnerText.Contains($this.CurrentState.RealVersion)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectNodes('/html/body/text()[2]/following-sibling::node()[count(.|/html/body/p[2]/preceding-sibling::node())=count(/html/body/p[2]/preceding-sibling::node())]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
