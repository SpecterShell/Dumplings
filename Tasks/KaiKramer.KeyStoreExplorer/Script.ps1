$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/kaikramer/keystore-explorer/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name -match 'setup' -and $_.name -notmatch 'no-jre' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
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

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://keystore-explorer.org/releases.html' | ConvertFrom-Html

      # The index page now only forwards to the release page for the current major version with a meta refresh.
      $RefreshNode = $Object2.SelectSingleNode('//meta[translate(@http-equiv, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz") = "refresh"]')
      if ($RefreshNode) {
        $RefreshTarget = [regex]::Match($RefreshNode.GetAttributeValue('content', ''), 'url=(.+)$', 'IgnoreCase').Groups[1].Value.Trim()
        if (-not [string]::IsNullOrWhiteSpace($RefreshTarget)) {
          $Object2 = Invoke-WebRequest -Uri (Join-Uri 'https://keystore-explorer.org/' $RefreshTarget) | ConvertFrom-Html
        }
      }

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@class='page-header' and contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.HasClass('page-header'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
