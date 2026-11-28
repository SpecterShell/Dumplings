$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/w01fb0ss/PiBot/releases/latest'

# Version
$this.CurrentState.Version = $Version = $Object1.tag_name -replace '^v'

# electron-builder NSIS. The release also ships the PiBot-Runner component and the macOS, Linux and
# Android artifacts; only the desktop app installer belongs to this package.
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name -eq "PiBot-${Version}-win-x64.exe" }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
      # The body is bilingual: an English lead paragraph, its Chinese counterpart, a download table
      # and then the two change lists. 更新内容 starts the Chinese one, so the English walk ends there
      # and the Chinese walk starts there.
      $ZhHeading = $ReleaseNotesObject.SelectSingleNode("./h2[contains(., '更新内容')]")
      $ZhIntro = $ReleaseNotesObject.SelectNodes('./p').Where({ $_.InnerText -match "[${CJK}]" }, 'First')[0]
      $Skip = $false
      $SkippedHeadingLevel = 0
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and $Node -ne $ZhHeading; $Node = $Node.NextSibling) {
        if ($Node.Name -match '^h([1-6])$') {
          $HeadingLevel = [int]$Matches[1]
          if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
            $Skip = $Node.InnerText -match '^\s*(Download|Downloads|Checksum|Hash|SHA-256)'
            if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
          }
        }
        if (-not $Skip -and $Node.Name -ne '#text' -and $Node -ne $ZhIntro) { $Node }
      }

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.html_url
      }

      $ReleaseNotesCNNodes = @($ZhIntro, $ZhHeading) + @($ZhHeading.SelectNodes('./following-sibling::node()'))

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesCNNodes | Where-Object { $_.Name -ne '#text' } | Get-TextContent | Format-Text
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
