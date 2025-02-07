$RepoOwner = 'Alex313031'
$RepoName = 'Thorium-Win'
# $RepoNameARM64 = 'Thorium-WOA'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"
$Version = $Object1.tag_name -creplace '^M'

# $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoNameARM64}/releases/latest"
# $VersionARM64 = $Object2.tag_name -creplace '^M'

# if ($Version -ne $VersionARM64) { throw 'ARM64 installer not released' }

# Version
$this.CurrentState.Version = $Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('SSE3') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'arm64'
#   InstallerUrl = $Object2.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('ARM64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

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
