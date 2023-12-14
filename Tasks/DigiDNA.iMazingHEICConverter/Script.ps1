$Object1 = Invoke-RestMethod -Uri 'https://downloads.imazing.com/com.DigiDNA.iMazingHEICConverterWindows.xml'

# Version
$Task.CurrentState.Version = $Object1[0].enclosure.version

# Installer
$InstallerUrl = $Object1[0].enclosure.url
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1[0].pubDate | Get-Date -AsUTC

# ReleaseNotesUrl
$ReleaseNotesUrl = $Object1[0].releaseNotesLink
$Task.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $InstallerUrl | Read-ProductVersionFromExe

    $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

    try {
      # ReleaseNotes (en-US)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectNodes('/html/body/div/p[2]/following-sibling::*') | Get-TextContent | Format-Text
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
