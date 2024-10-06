$RepoOwner = 'wixtoolset'
$RepoName = 'wix'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('AdditionalTools') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
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

    # The WiX 3 extractor doesn't work properly with the WiX 5 installer. Obtain necessary information from the metadata file.
    $Object2 = Invoke-RestMethod -Uri $Object1.assets.Where({ $_.name.EndsWith('.json') -and $_.name.Contains('AdditionalTools') }, 'First')[0].browser_download_url

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = $Object2.sha256
    # AppsAndFeaturesEntries + ProductCode
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode = $this.CurrentState.Installer[0]['ProductCode'] = $Object2.bundleCode
        UpgradeCode = $Object2.upgradeCode
      }
    )

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
