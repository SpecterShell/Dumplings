$Object1 = Invoke-RestMethod -Uri "https://ota.nvidia.com/release/available?product=GFN-win&version=$($this.LastState.Version ?? '2.0.47.119')&channel=OFFICIAL"

if ($Object1.Count -eq 0) {
  $this.Logging("The last version $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1[0].download_url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1[0].created_date

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://www.nvidia.com/en-us/geforce-now/release-highlights/' | ConvertFrom-Html

    try {
      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@class='tab-container']/div[1]//ul/li[contains(./div/a//h2, '$([regex]::Match($this.CurrentState.Version, '(\d+\.\d+\.\d+)').Groups[1].Value)')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div/div') | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
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
