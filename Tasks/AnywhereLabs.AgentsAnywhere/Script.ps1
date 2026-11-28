$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/anywhere-labs/Agents-Anywhere/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'

        $ReleaseNotesTitleNodes = $ReleaseNotesObject.SelectNodes('./h1[contains(., "Agents Anywhere")]')
        $EnglishTitleNode = $ReleaseNotesObject.SelectSingleNode('./h1[. = "English"]')
        if ($ReleaseNotesTitleNodes.Count -ge 2 -and $EnglishTitleNode) {
          $Skip = $false
          $SkippedHeadingLevel = 0
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNodes[1].NextSibling; $Node -and $Node.Name -ne 'h1'; $Node = $Node.NextSibling) {
            if ($Node.Name -match '^h([1-6])$') {
              $HeadingLevel = [int]$Matches[1]
              if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
                $Skip = $Node.InnerText -match 'Downloads|Download|Before You Upgrade|Installation|Android|iOS|Documentation and License'
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

          $Skip = $false
          $SkippedHeadingLevel = 0
          $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesTitleNodes[0].NextSibling; $Node -and $Node -cne $EnglishTitleNode; $Node = $Node.NextSibling) {
            if ($Node.Name -match '^h([1-6])$') {
              $HeadingLevel = [int]$Matches[1]
              if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
                $Skip = $Node.InnerText -match '下载|升级须知|安装说明|^Android$|iOS|文档与协议'
                if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
              }
            }
            if ($Node.Name -eq 'h1' -and $Node.InnerText.Trim() -eq '中文') { continue }
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
