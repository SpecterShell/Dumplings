$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/seakee/CPA-Manager-Plus/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$AssetX64 = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('amd64') -and $_.name -match 'windows' }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'portable'
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "$($AssetX64.name | Split-Path -LeafBase)/cpa-manager-plus.exe" })
  InstallerUrl         = $AssetX64.browser_download_url | ConvertTo-UnescapedUri
}
$AssetArm64 = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('arm64') -and $_.name -match 'windows' }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'arm64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'portable'
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "$($AssetArm64.name | Split-Path -LeafBase)/cpa-manager-plus.exe" })
  InstallerUrl         = $AssetArm64.browser_download_url | ConvertTo-UnescapedUri
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
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $ReleaseNotesMarkdown = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/seakee/CPA-Manager-Plus/HEAD/docs/release-notes/v$($this.CurrentState.Version)-en.md" | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
      $ReleaseNotesTitleNode = $ReleaseNotesMarkdown.SelectSingleNode('./h2[1]')
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('.|./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesMarkdown | Get-TextContent | Format-Text
        }
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = "https://github.com/seakee/CPA-Manager-Plus/blob/HEAD/docs/release-notes/v$($this.CurrentState.Version)-en.md"
      }
    } catch {
      $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }

    try {
      $ReleaseNotesCNMarkdown = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/seakee/CPA-Manager-Plus/HEAD/docs/release-notes/v$($this.CurrentState.Version)-zh.md" | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
      $ReleaseNotesCNTitleNode = $ReleaseNotesCNMarkdown.SelectSingleNode('./h2[1]')
      if ($ReleaseNotesCNTitleNode) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNTitleNode.SelectNodes('.|./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNMarkdown | Get-TextContent | Format-Text
        }
      }

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = "https://github.com/seakee/CPA-Manager-Plus/blob/HEAD/docs/release-notes/v$($this.CurrentState.Version)-zh.md"
      }
    } catch {
      $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
