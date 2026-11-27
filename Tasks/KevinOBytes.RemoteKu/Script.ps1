$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/KevinOBytes/RemoteKu/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

if ($this.CurrentState.Version -notmatch '^[0-9]+(\.[0-9]+)*$') {
  throw 'The latest release tag does not provide a numeric version.'
}

# Installer
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name -match 'Setup' -and $_.name -notmatch 'portable|update|BlockMap' }, 'First')[0]
if (-not $Asset) {
  throw 'The latest release does not provide a Windows NSIS setup installer.'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Asset.browser_download_url | ConvertTo-UnescapedUri
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

    # The release publishes no checksum asset, so the download cannot be verified against a published hash.

    try {
      # The release body is empty, so the change log lives in the English README section for the
      # current major and minor version.
      $RepoUrl = [string]$Object1.html_url -replace '/releases/.*$'

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $RepoUrl
      }

      $MajorMinor = ($this.CurrentState.Version -split '\.')[0..1] -join '.'
      $ReleaseNotesObject = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/KevinOBytes/RemoteKu/HEAD/README.md" | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
      $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectNodes('./h2').Where({ $_.InnerText.Trim() -match "^What'?s New in v$([regex]::Escape($MajorMinor))$" }, 'First')[0]
      if (-not $ReleaseNotesTitleNode) {
        throw "The README has no 'What's New in v$MajorMinor' section."
      }

      $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -notmatch '^h[12]$'; $Node = $Node.NextSibling) { $Node }

      # ReleaseNotes (en-US)
      $ReleaseNotes = $ReleaseNotesNodes | Get-TextContent | Format-Text
      if ([string]::IsNullOrWhiteSpace($ReleaseNotes)) {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      } else {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotes
        }
      }

      $ReleaseNotesAnchor = (($ReleaseNotesTitleNode.InnerText) -creplace '[^a-zA-Z0-9\-\s]+', '' -creplace '\s+', '-').ToLower()
      if ($ReleaseNotesAnchor) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = "$RepoUrl#$ReleaseNotesAnchor"
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
