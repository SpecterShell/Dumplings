$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/Kuddev/nebula/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name -match 'setup' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.html_url
      }

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.html_url
      }

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'

        $EnglishHeading = $ReleaseNotesObject.SelectSingleNode("/h2[contains(., 'English')]")
        $ChineseHeading = $ReleaseNotesObject.SelectSingleNode("/h2[contains(., '中文')]")
        if ($EnglishHeading -and $ChineseHeading) {
          $EnglishNodes = for ($Node = $EnglishHeading.NextSibling; $Node -and $Node.Name -notin @('h1', 'h2', 'hr'); $Node = $Node.NextSibling) { $Node }
          $ChineseNodes = for ($Node = $ChineseHeading.NextSibling; $Node -and $Node.Name -notin @('h1', 'h2', 'hr'); $Node = $Node.NextSibling) { $Node }

          if ($EnglishNodes) {
            # ReleaseNotes (en-US)
            $this.CurrentState.Locale += [ordered]@{
              Locale = 'en-US'
              Key    = 'ReleaseNotes'
              Value  = $EnglishNodes | Get-TextContent | Format-Text
            }
          } else {
            $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
          }

          if ($ChineseNodes) {
            # ReleaseNotes (zh-CN)
            $this.CurrentState.Locale += [ordered]@{
              Locale = 'zh-CN'
              Key    = 'ReleaseNotes'
              Value  = $ChineseNodes | Get-TextContent | Format-Text
            }
          } else {
            $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
          }
        } else {
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
          }
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
