$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/Sakyvo/k-switch/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.msi') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'

        $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectNodes('./*[self::h2 or self::h3]').Where({ $_.InnerText -notmatch "[${CJK}]" -and $_.InnerText -notmatch '^\s*(下载|Download)\s*$' }, 'First')
        $ReleaseNotesCNTitleNode = $ReleaseNotesObject.SelectNodes('./*[self::h2 or self::h3]').Where({ $_.InnerText.Trim() -eq '中文' }, 'First')
        if ($ReleaseNotesTitleNode -and $ReleaseNotesCNTitleNode) {
          $Skip = $false
          $SkippedHeadingLevel = 0
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode[0].NextSibling; $Node -and $Node -ne $ReleaseNotesCNTitleNode[0]; $Node = $Node.NextSibling) {
            if ($Node.Name -match '^h([1-6])$') {
              $HeadingLevel = [int]$Matches[1]
              if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
                $Skip = $Node.InnerText -match '^\s*(下载|Download)\s*$'
                if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
              }
              if ($Skip) { continue }
              $Node
              continue
            }
            if ($Skip) { continue }
            $Node
          }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }

          $Skip = $false
          $SkippedHeadingLevel = 0
          $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesCNTitleNode[0].NextSibling; $Node -and $Node.Name -ne 'hr'; $Node = $Node.NextSibling) {
            if ($Node.Name -match '^h([1-6])$') {
              $HeadingLevel = [int]$Matches[1]
              if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
                $Skip = $Node.InnerText -match '^\s*(下载|Download)\s*$'
                if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
              }
              if ($Skip) { continue }
              $Node
              continue
            }
            if ($Skip) { continue }
            $Node
          }
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesCNNodes | Get-TextContent | Format-Text
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
      } else {
        $this.Log("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
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
