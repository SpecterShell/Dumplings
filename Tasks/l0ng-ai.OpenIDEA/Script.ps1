$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/l0ng-ai/openidea/releases/latest'

# Version
$this.CurrentState.Version = $Version = $Object1.tag_name -replace '^v'

# The release ships a per-user NSIS setup.exe, a portable zip and per-architecture WiX MSIs, each
# with an updater .sig sibling. The MSI writes a standard Windows Installer ARP entry under a stable
# UpgradeCode and needs no scope switch, so it is the selected route and the other assets stay out.
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  Scope         = 'machine'
  InstallerUrl  = $Object1.assets.Where({ $_.name.StartsWith("OpenIDEA_${Version}_") -and $_.name.EndsWith('_x64_en-US.msi') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
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
      $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
      # The body folds the merged pull-request dump into a <details> block and appends a separate
      # 中文 summary, so the English change list is everything before the first of the two.
      $ChangelogNode = $ReleaseNotesObject.SelectSingleNode('./details')
      $ZhHeading = $ReleaseNotesObject.SelectSingleNode('./h2[contains(., "中文")]')
      $ZhNode = $ReleaseNotesObject.SelectSingleNode('./h2[contains(., "中文")]/following-sibling::p[1]')
      $Skip = $false
      $SkippedHeadingLevel = 0
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and $Node -ne $ChangelogNode -and $Node -ne $ZhHeading; $Node = $Node.NextSibling) {
        if ($Node.Name -match '^h([1-6])$') {
          $HeadingLevel = [int]$Matches[1]
          if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
            $Skip = $Node.InnerText -match '^\s*(Download|Downloads|Checksum|Hash|SHA-256)\s*$'
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

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.html_url
      }

      if ($ZhNode) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ZhNode | Get-TextContent | Format-Text
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
