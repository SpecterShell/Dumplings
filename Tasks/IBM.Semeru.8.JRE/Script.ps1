$RepoOwner = 'ibmruntimes'
$RepoName = 'semeru8-binaries'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

$VersionMatches = [regex]::Match($Object1.tag_name, 'jdk(?<Major>\d+)u(?<Patch>\d+)-?b0*(?<Build>\d+)')

# Version
$this.CurrentState.Version = "$($VersionMatches.Groups['Major']).0.$($VersionMatches.Groups['Patch']).$($VersionMatches.Groups['Build'])"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.msi') -and $_.name.Contains('jre') -and $_.name.Contains('x86-32') }, 'First').browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.msi') -and $_.name.Contains('jre') -and $_.name.Contains('x64') }, 'First').browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.html_url
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
