$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/hendrikdemir/budget/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

if ($this.CurrentState.Version -notmatch '^[0-9]+(\.[0-9]+)*$') {
  throw 'The latest release tag does not provide a numeric version.'
}

# Installer
# The macOS asset is a .dmg, so the single Budget-setup.exe is the only Windows artifact. The script
# sets ArchitecturesAllowed=x64compatible, and one asset covers both 64-bit architectures, so only the
# x64 entry is authored.
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.exe') }, 'First')[0]
if (-not $Asset) {
  throw 'The latest release does not provide a Windows setup installer.'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
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

    # The release publishes no checksum asset, so manifest generation computes InstallerSha256 from
    # the download.

    try {
      # ReleaseNotesUrl (en-GB)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-GB'
        Key    = 'ReleaseNotesUrl'
        Value  = [string]$Object1.html_url
      }

      if ([string]::IsNullOrWhiteSpace($Object1.body)) {
        $this.Log("No ReleaseNotes (en-GB) for version $($this.CurrentState.Version)", 'Warning')
      } else {
        # The body is a plain English bullet list of product changes, so the whole text is used.
        # ReleaseNotes (en-GB)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-GB'
          Key    = 'ReleaseNotes'
          Value  = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
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
