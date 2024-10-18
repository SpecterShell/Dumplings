$RepoOwner = 'maqi1520'
$RepoName = 'mdx-notes'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name.Contains('setup') -and -not $_.name.Contains('debug') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.msi') -and $_.name.Contains('x64') -and -not $_.name.Contains('debug') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()
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
