$RepoOwner = 'infinitered'
$RepoName = 'reactotron'

$Object1 = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases").Where({ $_.tag_name.StartsWith('reactotron-app') }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace 'reactotron-app@'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.msi') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType          = 'nullsoft'
  InstallerUrl           = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('Setup') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'
    }
  )
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

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = "https://github.com/${RepoOwner}/${RepoName}/blob/master/apps/reactotron-app/CHANGELOG.md"
      }

      $Object2 = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/${RepoOwner}/${RepoName}/master/apps/reactotron-app/CHANGELOG.md" | Convert-MarkdownToHtml

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/*[self::h2 or self::h3][contains(.//text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and ($Node.Name -notin @('h2', 'h3') -or $Node.InnerText -notmatch '\d+\.\d+\.\d+'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesNodes | Get-TextContent) -creplace 'Released \d{4}-\d{1,2}-\d{1,2}\n' | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl + '#' + ($ReleaseNotesTitleNode.InnerText -creplace '[^a-zA-Z0-9\-\s]+', '' -creplace '\s+', '-').ToLower()
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
