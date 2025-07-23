$RepoOwner = 'clash-verge-rev'
$RepoName = 'clash-verge-rev'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

if ($Object1.tag_name.Contains('alpha')) { throw 'Pre-release detected' }

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('setup') -and $_.name.Contains('x64') -and -not $_.name.Contains('fixed') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('setup') -and $_.name.Contains('arm64') -and -not $_.name.Contains('fixed') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body) -and -not $Object1.body.Contains('More new features are now supported.')) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        # Remove the table showing the UI in light/dark mode
        $ReleaseNotesObject.SelectNodes('//table[contains(., "Light") and contains(., "Dark")]').ForEach({ $_.Remove() })
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.SelectSingleNode("//h2[contains(., 'v$($this.CurrentState.Version)')]").NextSibling ?? $ReleaseNotesObject.ChildNodes[0]; $Node -and -not ($Node.Name -match '^h' -and $Node.InnerText.Contains('下载')); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }

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
