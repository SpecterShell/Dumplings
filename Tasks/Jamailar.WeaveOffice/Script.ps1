$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/Jamailar/Weave-Office/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name -match 'setup' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x86') -and $_.name -match 'setup' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('arm64') -and $_.name -match 'setup' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # ReleaseNotesUrl (zh-CN)
    $this.CurrentState.Locale += [ordered]@{ Locale = 'zh-CN'; Key = 'ReleaseNotesUrl'; Value = $null }

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
            $Skip = $Node.InnerText -match '^\s*(下载|校验和|签名与验证)\s*$'
            if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
          }
        }
        if (-not $Skip) { $Node }
      }
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
