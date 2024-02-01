$RepoOwner = 'quarto-dev'
$RepoName = 'quarto-cli'

$Object1 = Invoke-RestMethod -Uri 'https://quarto.org/docs/download/_download.json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.msi') -and $_.name.Contains('win') }, 'First')[0].download_url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.published.ToUniversalTime()

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
