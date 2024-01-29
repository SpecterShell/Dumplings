$RepoOwner = 'dynobo'
$RepoName = 'normcap'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.msi') -and $_.name.Contains('Windows') -and $_.name.Contains('x86_64') })[0].browser_download_url | ConvertTo-UnescapedUri
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = (Invoke-RestMethod -Uri "https://raw.githubusercontent.com/${RepoOwner}/${RepoName}/main/CHANGELOG" | ConvertFrom-Markdown).Html | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = "https://github.com/${RepoOwner}/${RepoName}/blob/main/CHANGELOG#" + ($ReleaseNotesTitleNode.InnerText -creplace '[^a-zA-Z0-9\-\s]+', '' -creplace '\s+', '-').ToLower()
        }
      } else {
        $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = "https://github.com/${RepoOwner}/${RepoName}/blob/main/CHANGELOG"
        }
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://github.com/${RepoOwner}/${RepoName}/blob/main/CHANGELOG"
      }
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
