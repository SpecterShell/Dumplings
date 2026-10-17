$Prefix = 'https://download.deepseek.com/dsh-desk/feeds/win-x64/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}nightly.yml" | ConvertFrom-ElectronBuilderUpdateFeed

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.Files[0].Url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ReleaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # The nightly version embeds the dsh release core, e.g. 0.1.7-rc.1.20260924.1 -> 0.1.7-rc.1
      $ReleaseVersion = $this.CurrentState.Version -match '^(.+)\.\d{8}\.\d+$' ? $Matches[1] : $this.CurrentState.Version

      $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/deepseek-ai/deepseek-harness/releases/tags/dsh-v${ReleaseVersion}"

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://github.com/deepseek-ai/deepseek-harness/releases'
      }

      if (-not [string]::IsNullOrWhiteSpace($Object2.body)) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $Object2.html_url
        }

        $ReleaseNotesObject = $Object2.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $ReleaseNotesEnTitleNode = $ReleaseNotesObject.SelectSingleNode("./h3[starts-with(@id, 'en-')]")
        $ReleaseNotesZhTitleNode = $ReleaseNotesObject.SelectSingleNode("./h3[starts-with(@id, 'cn-')]")

        if ($ReleaseNotesEnTitleNode) {
          $ReleaseNotesEnNodes = for ($Node = $ReleaseNotesEnTitleNode; $Node -and -not ($Node.Name -eq 'h3' -and $Node.Id -match '^cn-'); $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesEnNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }

        if ($ReleaseNotesZhTitleNode) {
          $ReleaseNotesZhNodes = for ($Node = $ReleaseNotesZhTitleNode; $Node -and -not ($Node.Name -eq 'h3' -and $Node.Id -match '^en-'); $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesZhNodes | Get-TextContent | Format-Text
          }
          # ReleaseNotesUrl (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotesUrl'
            Value  = $Object2.html_url
          }
        } else {
          $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
