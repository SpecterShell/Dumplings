$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/Keshav-Madhav/tidewall/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Velopack cross-packs a Setup.exe per Windows RID. The same release also carries the full and delta
# .nupkg payloads, per-version patch archives, the macOS disk image and the update feeds, so the name
# prefix and the .exe extension are tested as separate predicates.
$Asset = $Object1.assets.Where({ $_.name.StartsWith('Tidewall-win-x64-Setup') -and $_.name.EndsWith('.exe') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = $Asset.browser_download_url | ConvertTo-UnescapedUri
}

$Asset = $Object1.assets.Where({ $_.name.StartsWith('Tidewall-win-arm64-Setup') -and $_.name.EndsWith('.exe') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'exe'
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

    try {
      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesHtml = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        # The body is split per platform. Only the Windows section describes this installer, so any
        # other platform heading starts a skip that runs until a heading of the same or a shallower
        # level appears.
        $Skip = $false
        $SkippedHeadingLevel = 0
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesHtml.ChildNodes[0]; $Node; $Node = $Node.NextSibling) {
          if ($Node.Name -match '^h([1-6])$') {
            $HeadingLevel = [int]$Matches[1]
            if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
              $Skip = $Node.InnerText -match '^\s*(Download|Downloads|Checksum|Hash|SHA-256|Mac|macOS|iMac|Linux|Ubuntu|Debian|RPM|deb|apk|Android|iOS)\b'
              if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
            }
          }
          if (-not $Skip -and $Node.Name -ne '#text') { $Node }
        }

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
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
