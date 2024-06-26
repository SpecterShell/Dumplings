$RepoOwner = 'SAP'
$RepoName = 'SapMachine'

$Object1 = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/SAP/SapMachine/gh-pages/assets/data/sapmachine_releases.json').assets.'17'.releases[0]

# Version
$this.CurrentState.Version = $Object1.tag -creplace '^sapmachine-'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.jre.'windows-x64-installer'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/tags/$($Object1.tag)"

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.published_at.ToUniversalTime()

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object2.html_url
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
