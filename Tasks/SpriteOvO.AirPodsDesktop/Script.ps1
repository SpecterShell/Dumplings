$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/SpriteOvO/AirPodsDesktop/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('win64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'

        $ReleaseNotesTWTitleNode = $ReleaseNotesObject.SelectNodes('./h2[contains(., "繁體中文")]')
        if ($ReleaseNotesTWTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and $Node.Name -ne 'hr' -and -not $($Node.Name -in @('h1', 'h2') -and $Node.InnerText -match '繁體中文|Checksum'); $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }

          $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesTWTitleNode[0].NextSibling; $Node -and $Node.Name -ne 'hr' -and -not $($Node.Name -in @('h1', 'h2') -and $Node.InnerText -match 'Checksum'); $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (zh-TW)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-TW'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotes = $ReleaseNotesCNNodes | Get-TextContent | Format-Text
          }

          $Object2 = Invoke-RestMethod -Uri 'https://api.zhconvert.org/convert' -Method Post -Body @{ text = $ReleaseNotes; converter = 'China' }
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $Object2.data.text
          }
          $this.Log('Powered by zhconvert API: https://zhconvert.org/')
        } else {
          $this.Log("No ReleaseNotes (zh-TW) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
