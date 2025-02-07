$RepoOwner = 'rime'
$RepoName = 'weasel'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('installer') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      $ReleaseNotes = $null
      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $Object2 = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h2[contains(., '$($this.CurrentState.Version)')]")
        if ($ReleaseNotesTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node; $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (zh-Hant)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-Hant'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotes = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (zh-Hant) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotes (zh-Hant) for version $($this.CurrentState.Version)", 'Warning')
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

    try {
      if ($ReleaseNotes) {
        $Object3 = Invoke-RestMethod -Uri 'https://api.zhconvert.org/convert' -Method Post -Body @{ text = $ReleaseNotes; converter = 'Simplified' }
        # ReleaseNotes (zh-Hans)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-Hans'
          Key    = 'ReleaseNotes'
          Value  = $Object3.data.text
        }
        $this.Log('Powered by zhconvert API: https://zhconvert.org/')
      } else {
        $this.Log("No ReleaseNotes (zh-Hans) for version $($this.CurrentState.Version)", 'Warning')
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
