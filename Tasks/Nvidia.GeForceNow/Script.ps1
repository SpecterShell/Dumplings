$Object1 = Invoke-RestMethod -Uri "https://ota.nvidia.com/release/available?product=GFN-win&version=$($this.LastState.Version ?? '2.0.47.119')&channel=OFFICIAL&deviceId=0"

if ($Object1.Count -eq 0) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1[0].download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1[0].created_date
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.nvidia.com/en-us/geforce-now/release-highlights/' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@class='tab-container']/div[1]//ul/li[contains(./div/a//h2, '$([regex]::Match($this.CurrentState.Version, '(\d+\.\d+\.\d+)').Groups[1].Value)')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div/div') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
