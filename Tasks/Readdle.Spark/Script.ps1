$Object1 = Invoke-RestMethod -Uri 'https://downloads.sparkmailapp.com/Spark3/win/dist/appcast.xml'

# Version
$Task.CurrentState.Version = [regex]::Match($Object1.enclosure.version, '^(\d+\.\d+\.\d+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.enclosure.url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.pubDate | Get-Date -AsUTC

# ReleaseNotesUrl
$ReleaseNotesUrl = $Object1.releaseNotesLink
$Task.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

    try {
      if ($Object2.SelectSingleNode('/html/body/p[1]/strong').InnerText.Contains($Task.CurrentState.Version)) {
        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectNodes('/html/body/text()[2]/following-sibling::node()[count(.|/html/body/p[2]/preceding-sibling::node())=count(/html/body/p[2]/preceding-sibling::node())]') | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
