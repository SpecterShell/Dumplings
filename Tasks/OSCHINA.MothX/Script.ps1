$Object1 = (Invoke-GitHubApi -Uri 'https://api.github.com/repos/oschina/mothx/releases').Where({ -not $_.draft -and -not $_.prerelease }) | Sort-Object -Property { [ChunkVersion]($_.tag_name -replace '^v') } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name -match 'windows' -and $_.name.Contains('amd64') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'portable'
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "$($Asset.name | Split-Path -LeafBase)\mothx.exe" })
  InstallerUrl         = $Asset.browser_download_url | ConvertTo-UnescapedUri
}
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name -match 'windows' -and $_.name.Contains('arm64') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'arm64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'portable'
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "$($Asset.name | Split-Path -LeafBase)\mothx.exe" })
  InstallerUrl         = $Asset.browser_download_url | ConvertTo-UnescapedUri
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
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'https://github.com/oschina/mothx/blob/HEAD/docs/en/changelog.md'
      }

      $Object2 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/oschina/mothx/HEAD/docs/en/changelog.md' | Convert-MarkdownToHtml

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
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
          Value  = $ReleaseNotesUrl + '#' + ($ReleaseNotesTitleNode.InnerText -replace '[^a-zA-Z0-9\-\s]+', '' -replace '\s+', '-').ToLower()
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesCNUrl = 'https://github.com/oschina/mothx/blob/HEAD/docs/zh/changelog.md'
      }

      $Object3 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/oschina/mothx/HEAD/docs/zh/changelog.md' | Convert-MarkdownToHtml

      $ReleaseNotesCNTitleNode = $Object3.SelectSingleNode("/h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesCNTitleNode) {
        $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesCNTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesCNUrl + '#' + ($ReleaseNotesCNTitleNode.InnerText -replace '[^a-zA-Z0-9\-\s]+', '' -replace '\s+', '-').ToLower()
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
