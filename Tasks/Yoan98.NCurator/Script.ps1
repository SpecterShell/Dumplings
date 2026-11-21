
$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/Yoan98/Ncurator/releases?per_page=100'
$VersionedReleases = foreach ($Release in $Object1) {
  if (-not $Release.draft -and -not $Release.prerelease -and $Release.tag_name -match '^windows-v(?<Version>\d+(?:\.\d+)*)$') {
    [pscustomobject]@{
      Release = $Release
      Version = [ChunkVersion]$Matches.Version
    }
  }
}
if (-not $VersionedReleases) {
  throw 'No Windows release was found in the repository.'
}

$Object2 = ($VersionedReleases | Sort-Object -Property Version -Bottom 1).Release

# Version
$this.CurrentState.Version = $Object2.tag_name -replace '^windows-v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object2.assets.Where({ $_.name.EndsWith('.exe') -and $_.name -match 'Windows' -and $_.name.Contains('x64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.published_at.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    function Get-ReleaseNotesSection {
      param(
        [string]$Uri,
        [string]$Version
      )

      $Document = Invoke-WebRequest -Uri $Uri -UserAgent $DumplingsBrowserUserAgent | ConvertFrom-Html
      $ReleaseNotesNode = $Document.SelectSingleNode("//article[contains(@class, 'changelog-entry') and .//h3[@class = 'changelog-version' and normalize-space(.) = 'v$Version'] and .//span[contains(@class, 'changelog-platform-tag') and normalize-space(.) = 'Windows']]/div[@class = 'changelog-groups']")
      if (-not $ReleaseNotesNode) { return $null }

      # The list markers are decorative spans and would split every item across two lines.
      $ReleaseNotesNode.SelectNodes('.//span[contains(@class, "changelog-item-mark")]').ForEach({ $_.Remove() })

      $ReleaseNotesNode | Get-TextContent | Format-Text
    }

    try {
      $ReleaseNotes = Get-ReleaseNotesSection -Uri 'https://www.ncurator.com/en/changelog' -Version $this.CurrentState.Version
      if ($ReleaseNotes) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotes
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $ReleaseNotes = Get-ReleaseNotesSection -Uri 'https://www.guanzhangai.cn/zh/changelog' -Version $this.CurrentState.Version
      if ($ReleaseNotes) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotes
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
