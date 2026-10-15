$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/yicheng47/runner/releases/latest'

# Version — the release tag omits the build stamp carried by the asset name and the installed ARP entry
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name -match 'Setup' }, 'First')[0]
$this.CurrentState.Version = $Asset.name -replace '^Runner-Setup-' -replace '-x64\.exe$'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = $Asset.browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'

        $ReleaseNotesTitleNode = $ReleaseNotesObject.ChildNodes[0]
        $ReleaseNotesCNTitleNode = $ReleaseNotesObject.SelectSingleNode('./details/summary[contains(., "中文")]')
        if ($ReleaseNotesTitleNode -and $ReleaseNotesCNTitleNode) {
          $Skip = $false
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode; $Node -and $Node.Name -notin @('h1', 'details', 'hr'); $Node = $Node.NextSibling) {
            if ($Node.Name -eq 'h2') { $Skip = $Node.InnerText -match 'Download|Upgrade|Windows|macOS' }
            if (-not $Skip) { $Node }
          }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }

          $Skip = $false
          $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesCNTitleNode.NextSibling; $Node -and $Node.Name -notin @('h1', 'details', 'hr'); $Node = $Node.NextSibling) {
            if ($Node.Name -eq 'h2') { $Skip = $Node.InnerText -match '下载|升级|Windows|macOS' }
            if (-not $Skip) { $Node }
          }
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesCNNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
          }
        }
      } else {
        $this.Log("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
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
