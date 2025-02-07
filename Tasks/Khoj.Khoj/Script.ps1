$Object1 = Invoke-RestMethod -Uri 'https://download.todesktop.com/230828upu3vonlt/td-latest.json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.artifacts.nsis.x64.url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.createdAt.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $RepoOwner = 'khoj-ai'
      $RepoName = 'khoj'

      $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/tags/$($this.CurrentState.Version)"

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object2.body)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.body | Convert-MarkdownToHtml -Extensions $MarkdigSoftlineBreakAsHardlineExtension | Get-TextContent | Format-Text
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
