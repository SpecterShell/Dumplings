$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/sligter/qunica/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name -match 'setup' -and $_.name -notmatch 'portable' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('arm64') -and $_.name -match 'setup' -and $_.name -notmatch 'portable' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'

        $Skip = $false
        $SkippedHeadingLevel = 0
        $IsChinese = $false
        $ReleaseNotesEnNodes = [System.Collections.Generic.List[object]]::new()
        $ReleaseNotesZhNodes = [System.Collections.Generic.List[object]]::new()
        foreach ($Node in $ReleaseNotesObject.ChildNodes) {
          if ($Node.Name -eq '#text' -and [string]::IsNullOrWhiteSpace($Node.InnerText)) { continue }
          if ($Node.Name -match '^h([1-6])$') {
            $HeadingLevel = [int]$Matches[1]
            if ($Node.InnerText -match '中文更新说明') {
              $IsChinese = $true
              $Skip = $false
              $SkippedHeadingLevel = 0
              continue
            }
            if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
              $Skip = $Node.InnerText -match '^\s*Downloads and upgrade notes\s*$'
              if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
            }
          }
          if ($Skip) { continue }
          if ($IsChinese) { $ReleaseNotesZhNodes.Add($Node) } else { $ReleaseNotesEnNodes.Add($Node) }
        }

        $ReleaseNotesEn = $ReleaseNotesEnNodes | Get-TextContent | Format-Text
        if ($ReleaseNotesEn) {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesEn
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }

        $ReleaseNotesZh = $ReleaseNotesZhNodes | Get-TextContent | Format-Text
        if ($ReleaseNotesZh) {
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesZh
          }
        } else {
          $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
