# The publisher publishes one release per platform, so releases/latest may point at a non-Windows release. Pick the latest stable -windows release instead.
$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/oldcai/LazyTyper-releases/releases?per_page=100'
$Object1 = $Object1.Where({ $_.tag_name.EndsWith('-windows') -and -not $_.prerelease -and -not $_.draft }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v' -replace '-windows$'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name -match 'setup' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      # if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
      #   # ReleaseNotes (zh-CN)
      #   $this.CurrentState.Locale += [ordered]@{
      #     Locale = 'zh-CN'
      #     Key    = 'ReleaseNotes'
      #     Value  = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
      #   }
      # } else {
      #   $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      # }

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
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
