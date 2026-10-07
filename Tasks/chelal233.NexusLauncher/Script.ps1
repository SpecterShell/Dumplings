$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/chelal233/dsh-nexus/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name -notmatch 'portable' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('arm64') -and $_.name -notmatch 'portable' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'

        $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectNodes('./h2').Where({ $_.SelectSingleNode('./following-sibling::*[1]').InnerText -notmatch "[${CJK}]" }, 'First')
        $ReleaseNotesCNTitleNode = $ReleaseNotesObject.SelectNodes('./h2').Where({ $_.SelectSingleNode('./following-sibling::*[1]').InnerText -match "[${CJK}]" }, 'First')
        if ($ReleaseNotesTitleNode -and $ReleaseNotesCNTitleNode) {
          $Skip = $false
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode[0].NextSibling; $Node -and $Node.Name -notin @('h1', 'h2', 'hr'); $Node = $Node.NextSibling) {
            if ($Node.Name -eq 'h3') { $Skip = $Node.InnerText -match 'Downloads|Provenance' }
            if (-not $Skip) { $Node }
          }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }

          $Skip = $false
          $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesCNTitleNode[0].NextSibling; $Node -and $Node.Name -notin @('h1', 'h2', 'hr'); $Node = $Node.NextSibling) {
            if ($Node.Name -eq 'h3') { $Skip = $Node.InnerText -match '下载|来源' }
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
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
