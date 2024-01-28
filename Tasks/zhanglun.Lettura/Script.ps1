$RepoOwner = 'zhanglun'
$RepoName = 'lettura'

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
