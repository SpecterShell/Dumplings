$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/arvindell/sessiongraph/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# The release names both Windows bundles without the version, so take the versioned tag path that
# browser_download_url already provides. The NSIS setup installs per user and the WiX MSI installs
# machine wide; the MSI is the selected route, so the .exe and its updater .sig stay out of the manifest.
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  Scope         = 'machine'
  InstallerUrl  = $Object1.assets.Where({ $_.name -eq 'sessiongraph-win32-x64.msi' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
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
      # The generated body lists the merged changes and ends with a compare link that duplicates ReleaseNotesUrl.
      $Body = ($Object1.body -split '\r?\n' | Where-Object { $_ -and $_ -notmatch '^\*\*Full Changelog\*\*' }) -join "`n"
      if ($Body) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

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
