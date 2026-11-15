$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/OpenAEC-Foundation/open-paint-studio/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('exe') -and $_.name.Contains('x64') -and $_.name -match 'setup' -and $_.name -notmatch 'user' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode('./*[(self::h1 or self::h2) and contains(., "English")]')
        $ReleaseNotesNLTitleNode = $ReleaseNotesObject.SelectSingleNode('./*[(self::h1 or self::h2) and contains(., "Nederlands")]')
        if ($ReleaseNotesTitleNode -and $ReleaseNotesNLTitleNode) {
          $Skip = $false
          $SkippedHeadingLevel = 0
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode[0].NextSibling; $Node -and $Node.Name -ne 'hr' -and -not ($Node.Name -match '^h\d$' -and $Node.InnerText -match 'Nederlands'); $Node = $Node.NextSibling) {
            if ($Node.Name -match '^h([1-6])$') {
              $HeadingLevel = [int]$Matches[1]
              if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
                $Skip = $Node.InnerText -match 'Downloads'
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
          $ReleaseNotesNLNodes = for ($Node = $ReleaseNotesNLTitleNode[0].NextSibling; $Node -and $Node.Name -ne 'hr' -and -not ($Node.Name -match '^h\d$' -and $Node.InnerText -match 'English'); $Node = $Node.NextSibling) {
            if ($Node.Name -match '^h([1-6])$') {
              $HeadingLevel = [int]$Matches[1]
              if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
                $Skip = $Node.InnerText -match 'Downloads'
                if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
              }
            }
            if (-not $Skip) { $Node }
          }
          # ReleaseNotes (nl-NL)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'nl-NL'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNLNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (nl-NL) for version $($this.CurrentState.Version)", 'Warning')
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
