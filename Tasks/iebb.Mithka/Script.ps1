# The newest stable release can ship assets for one platform only, e.g. v1.13.11 carries macOS archives alone,
# so walk the stable releases and keep those that publish Windows setup installers for both architectures.
$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/iebb/mithka/releases?per_page=100'
$WindowsReleases = foreach ($Release in $Object1) {
  $X64Asset = $Release.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('windows') -and $_.name.Contains('x64') -and $_.name -match 'setup' }, 'First')
  $Arm64Asset = $Release.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('windows') -and $_.name.Contains('arm64') -and $_.name -match 'setup' }, 'First')
  if (-not $Release.draft -and -not $Release.prerelease -and $X64Asset -and $Arm64Asset) {
    [pscustomobject]@{
      Release    = $Release
      X64Asset   = $X64Asset[0]
      Arm64Asset = $Arm64Asset[0]
      Version    = $Release.tag_name -replace '^v'
    }
  }
}
if (-not $WindowsReleases) {
  throw 'No Windows installer was found in the stable releases of iebb/mithka.'
}

$Object2 = $WindowsReleases | Sort-Object -Property { [ChunkVersion]$_.Version } -Bottom 1

# Version
$this.CurrentState.Version = $Object2.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = $Object2.X64Asset.browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'inno'
  InstallerUrl  = $Object2.Arm64Asset.browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.Release.published_at.ToUniversalTime()

      # The release body writes every paragraph in English first and in Simplified Chinese afterwards,
      # then appends a source commit trailer that is not a product change.
      $Paragraphs = @($Object2.Release.body -split '\r?\n\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^Source:' })
      $EnglishReleaseNotes = $Paragraphs.Where({ $_ -notmatch '[\u4e00-\u9fff]' }) -join "`n`n"
      $ChineseReleaseNotes = $Paragraphs.Where({ $_ -match '[\u4e00-\u9fff]' }) -join "`n`n"

      if ($EnglishReleaseNotes) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $EnglishReleaseNotes | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      if ($ChineseReleaseNotes) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ChineseReleaseNotes | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object2.Release.html_url
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
