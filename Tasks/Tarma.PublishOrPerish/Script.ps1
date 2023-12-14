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

switch ($Task.Check()) {
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
        $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
