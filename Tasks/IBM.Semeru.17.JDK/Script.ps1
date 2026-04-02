$RepoOwner = 'ibmruntimes'
$RepoName = 'semeru17-binaries'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

$VersionMatches = [regex]::Match($Object1.tag_name, 'jdk-(?<Major>\d+)(?:\.(?<Minor>\d+))?(?:\.(?<Patch>\d+))?\+(?<Build>\d+)')

$VersionBuilder = [System.Text.StringBuilder]::new($VersionMatches.Groups['Major'].Value).Append('.')
$VersionBuilder = $VersionMatches.Groups['Minor'].Success ? $VersionBuilder.Append($VersionMatches.Groups['Minor'].Value) : $VersionBuilder.Append('0')
$VersionBuilder = $VersionBuilder.Append('.')
$VersionBuilder = $VersionMatches.Groups['Patch'].Success ? $VersionBuilder.Append($VersionMatches.Groups['Patch'].Value) : $VersionBuilder.Append('0')
$VersionBuilder = $VersionBuilder.Append('.').Append($VersionMatches.Groups['Build'].Value)

# Version
$this.CurrentState.Version = $VersionBuilder.ToString()

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.msi') -and $_.name.Contains('jdk') }, 'First').browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.html_url
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
