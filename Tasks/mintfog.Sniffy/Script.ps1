$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/mintfog/sniffy/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('windows') -and $_.name.Contains('amd64') -and $_.name -match 'Desktop' -and $_.name -match 'Installer' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
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
            $Skip = $Node.InnerText -match '^\s*(下载|下载安装|相关文档|校验和)\s*$'
            if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
          }
        }
        if (-not $Skip -and $Node.Name -ne 'hr') { $Node }
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
