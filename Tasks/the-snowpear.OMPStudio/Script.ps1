$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/the-snowpear/omp-studio/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name -match 'Setup' -and $_.name.Contains('x64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name -match 'Setup' -and $_.name.Contains('arm64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        # electron-builder release bodies pair a Chinese section with an "English" heading and
        # carry per-platform download tables, so drop every table and every download section.
        $SkipPattern = '^\s*(下载安装|独立\s*web\s*/\s*ssh\s*运行环境|downloads?|standalone\s+web\s*/\s+ssh\s+environments?)\s*$'

        $ReleaseNotesCNTitleNode = $ReleaseNotesObject.SelectNodes('./h2').Where({ $_.InnerText.Trim() -eq 'English' }, 'First')

        $Skip = $false
        $SkippedHeadingLevel = 0
        $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node; $Node = $Node.NextSibling) {
          if ($ReleaseNotesCNTitleNode -and $Node -eq $ReleaseNotesCNTitleNode[0]) { break }
          if ($Node.Name -match '^h([1-6])$') {
            $HeadingLevel = [int]$Matches[1]
            if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
              $Skip = $Node.InnerText -match $SkipPattern
              if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
            }
            if ($Skip -or $HeadingLevel -eq 1) { continue }
            $Node
            continue
          }
          if ($Skip -or $Node.Name -eq 'table') { continue }
          $Node
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNodes | Get-TextContent | Format-Text
        }

        $Skip = $false
        $SkippedHeadingLevel = 0
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesCNTitleNode[0].NextSibling; $Node; $Node = $Node.NextSibling) {
          if ($Node.Name -match '^h([1-6])$') {
            $HeadingLevel = [int]$Matches[1]
            if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
              $Skip = $Node.InnerText -match $SkipPattern
              if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
            }
            if ($Skip) { continue }
            $Node
            continue
          }
          if ($Skip -or $Node.Name -eq 'table') { continue }
          $Node
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
