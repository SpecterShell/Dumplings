$Object1 = Invoke-RestMethod -Uri 'https://github.com/2716190547/zmark/releases/latest/download/latest-windows.json'

# Version
$this.CurrentState.Version = [string]$Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = [string]$Object1.url
}

if ($this.CurrentState.Version -notmatch '^[0-9]+(\.[0-9]+)*$' -or $this.CurrentState.Installer[0].InstallerUrl -notmatch '-setup\.exe$') {
  throw 'The Windows update manifest does not provide a versioned setup installer.'
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

    $InstallerUrl = [string]$Object1.url
    $this.InstallerFiles[$InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerUrl
    if ((Get-FileHash -LiteralPath $InstallerFile -Algorithm SHA256).Hash -ine [string]$Object1.sha256) {
      throw 'The downloaded installer does not match the SHA-256 published by the update manifest.'
    }

    try {
      $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/2716190547/zmark/releases/tags/v$($this.CurrentState.Version)"

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = [string]$Object2.html_url
      }

      if ([string]::IsNullOrWhiteSpace($Object2.body)) {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      } else {
        # The release body is Chinese only, and its trailing sections describe packaging,
        # distribution limits, and CI gate counts rather than product changes.
        $ReleaseNotesObject = $Object2.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $ReleaseNotesNodes = [System.Collections.Generic.List[object]]::new()
        $Skip = $false
        $SkippedHeadingLevel = 0
        foreach ($Node in $ReleaseNotesObject.ChildNodes) {
          if ($Node.Name -match '^h([1-6])$') {
            $HeadingLevel = [int]$Matches[1]
            if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
              $Skip = $Node.InnerText -match '下载与限制|发布前验证|构建来源'
              if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
            }
          }
          if ($Skip -or $Node.Name -eq 'h1') { continue }
          $ReleaseNotesNodes.Add($Node)
        }

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
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
