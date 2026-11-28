$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/zenineasa/Konjugate/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('-setup.exe') -and $_.name.Contains('x64') -and $_.name -match 'Konjugate' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      $ReleaseNotesDocument = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
      $Skip = $false
      $SkippedHeadingLevel = 0
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesDocument.ChildNodes[0]; $Node; $Node = $Node.NextSibling) {
        if ($Node.Name -match '^h([1-6])$') {
          $HeadingLevel = [int]$Matches[1]
          if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
            $Skip = $Node.InnerText -match '^\s*(Install(?:ation)?|Downloads?|Hash(?:es)?|Checksums?|SHA-256|下载|校验和)\s*$'
            if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
          }
          continue
        }
        if ($Skip) { continue }
        if ($Node.Name -eq 'blockquote') { continue }
        if ($Node.InnerText -match '^\s*Full Changelog') { continue }
        $Node
      }
      $ReleaseNotes = $ReleaseNotesNodes | Get-TextContent | Format-Text
      if ($ReleaseNotes) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotes
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
