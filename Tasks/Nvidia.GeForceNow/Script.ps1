$Object1 = Invoke-RestMethod -Uri "https://ota.nvidia.com/release/available?product=GFN-win&version=$($Task.LastState.Version ?? '2.0.47.119')&channel=OFFICIAL"

if ($Object1.Length -eq 0) {
  $Task.Logging("The last version $($Task.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# Version
$Task.CurrentState.Version = $Object1[0].version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1[0].download_url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1[0].created_date

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://www.nvidia.com/en-us/geforce-now/release-highlights/' | ConvertFrom-Html

    try {
      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@class='tab-container']/div[1]//ul/li[contains(./div/a//h2, '$([regex]::Match($Task.CurrentState.Version, '(\d+\.\d+\.\d+)').Groups[1].Value)')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div/div') | Get-TextContent | Format-Text
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
