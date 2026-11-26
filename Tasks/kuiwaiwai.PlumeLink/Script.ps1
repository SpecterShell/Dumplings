$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/kuiwaiwai/plumelink/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

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

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesDocument = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'

        # ReleaseNotes (en-US): English sections, excluding downloads, checksums and the Chinese summary
        $Skip = $false
        $SkippedHeadingLevel = 0
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesDocument.ChildNodes[0]; $Node; $Node = $Node.NextSibling) {
          if ($Node.Name -match '^h([1-6])$') {
            $HeadingLevel = [int]$Matches[1]
            if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
              $Skip = $Node.InnerText -match '^\s*(Downloads?|Hash(?:es)?|Checksums?|SHA-256|下载|校验和)\s*$' -or $Node.InnerText.Trim() -eq '中文说明'
              if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
            }
          }
          if (-not $Skip) { $Node }
        }

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotes (zh-CN): the 中文说明 section that follows the English notes
        $IsChineseSection = $false
        $ChineseHeadingLevel = 0
        $ChineseNodes = for ($Node = $ReleaseNotesDocument.ChildNodes[0]; $Node; $Node = $Node.NextSibling) {
          if ($Node.Name -match '^h([1-6])$') {
            $HeadingLevel = [int]$Matches[1]
            if ($IsChineseSection -and $HeadingLevel -le $ChineseHeadingLevel) {
              break
            }
            if (-not $IsChineseSection -and $Node.InnerText.Trim() -eq '中文说明') {
              $IsChineseSection = $true
              $ChineseHeadingLevel = $HeadingLevel
              continue
            }
          }
          if ($IsChineseSection) { $Node }
        }

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ChineseNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US, zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
