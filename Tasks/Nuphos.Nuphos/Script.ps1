# The desktop feed carries a universal Windows build together with the per-architecture ones, so the
# two manifest entries are selected by their -x64 and -arm64 asset names instead of Files[0]. The
# marketing redirect https://nuphos.ai/api/desktop/download?platform=windows always serves the newest
# build, so the manifest keeps the versioned S3 asset URLs the feed names.
$Prefix = 'https://nuphos-releases.s3.amazonaws.com/desktop/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-ElectronBuilderUpdateFeed

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = Join-Uri $Prefix $Object1.Files.Where({ $_.Url.Contains('-x64') }, 'First')[0].Url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'nullsoft'
  InstallerUrl  = Join-Uri $Prefix $Object1.Files.Where({ $_.Url.Contains('-arm64') }, 'First')[0].Url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # Desktop tags are bare 'v<version>'; cli-, backend-, ios- and runtime- tags are separate releases.
    $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/nuphos/nuphos/releases/tags/v$($this.CurrentState.Version)"

    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.published_at.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotes (en-US)
      $ReleaseNotesDocument = $Object2.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
      $ReleaseNotesTitleNode = $ReleaseNotesDocument.SelectSingleNode('//h2[contains(., "Highlights")]')
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }

        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object2.html_url
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
