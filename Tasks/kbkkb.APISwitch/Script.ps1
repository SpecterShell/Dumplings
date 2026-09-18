$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/kbkkb/APISwitch/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name -match 'Setup' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'

        $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectNodes('./h3[contains(., "English")]')
        $ReleaseNotesCNTitleNode = $ReleaseNotesObject.SelectNodes('./h3[contains(., "中文")]')
        if ($ReleaseNotesTitleNode -and $ReleaseNotesCNTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode[0].NextSibling; $Node -and $Node.Name -notin @('h1', 'h2', 'h3', 'hr') -and -not ($Node.Name -eq 'h4' -and $Node.InnerText -match 'Downloads'); $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }

          $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesCNTitleNode[0].NextSibling; $Node -and $Node.Name -notin @('h1', 'h2', 'h3', 'hr') -and -not ($Node.Name -eq 'h4' -and $Node.InnerText -match '下载'); $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesCNNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
          }
        }
      } else {
        $this.Log("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
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
