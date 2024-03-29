$RepoOwner = 'breeze2'
$RepoName = 'dsu-manager-guides'

$Object1 = Invoke-RestMethod -Uri "https://github.com/${RepoOwner}/${RepoName}/releases/latest/download/latest.json"

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.platforms.'windows-x86_64'.url -creplace '\.zip$'
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.pub_date.ToUniversalTime()

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = "https://github.com/${RepoOwner}/${RepoName}/releases/tag/v$($this.CurrentState.Version)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri "https://github.com/${RepoOwner}/${RepoName}/releases.atom").Where({ $_.id.EndsWith("v$($this.CurrentState.Version)") }, 'First')[0]

      if ($Object2.content.'#text' -ne 'No content.') {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.content.'#text' | ConvertFrom-Html | Get-TextContent | Format-Text
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
