$Object1 = Invoke-RestMethod -Uri 'https://harzing.com/download/pop8.txt' | ConvertFrom-Ini

# Version
$Task.CurrentState.Version = $Object1.main.Version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://harzing.com/download/PoP8Setup.exe'
}

# ReleaseNotesUrl
$ReleaseNotesUrl = $Object1.main.NewsURL
$Task.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

    try {
      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@id='content']/article/table/tbody/tr[contains(./td[1]/text(), '$([regex]::Match($Task.CurrentState.Version, '(\d+\.\d+\.\d+)').Groups[1].Value)')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./td[2]') | Get-TextContent | Format-Text
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
