$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/fwilhe2/grind/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

if ($this.CurrentState.Version -notmatch '^[0-9]+(\.[0-9]+)*$') {
  throw 'The latest release tag does not provide a numeric version.'
}

# Installer
# The name labels the platform as win32, not the bitness: the paired x86_64 token is the architecture,
# and the release body describes this single-file build as "Windows, x64 and Arm".
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name -match 'win32' -and $_.name.Contains('x86_64') }, 'First')[0]
if (-not $Asset) {
  throw 'The latest release does not provide the Windows x64 single-file grind executable.'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'portable'
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

    # The release pairs each .sha256 asset with a -v<version>-<target> archive, never with this
    # single-file executable, so there is no published checksum to verify the download against.

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = [string]$Object1.html_url
      }

      if ([string]::IsNullOrWhiteSpace($Object1.body)) {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      } else {
        # The body is English only, and its leading "## Download" section is per-platform install
        # instructions, package tables, and attestation commands.
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $ReleaseNotesNodes = [System.Collections.Generic.List[object]]::new()
        $Skip = $false
        $SkippedHeadingLevel = 0
        foreach ($Node in $ReleaseNotesObject.ChildNodes) {
          if ($Node.Name -match '^h([1-6])$') {
            $HeadingLevel = [int]$Matches[1]
            if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
              $Skip = $Node.InnerText -match '(?i)^\s*(Downloads?|Hash(?:es)?|Checksums?|SHA-256)\s*$'
              if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
            }
          }
          if ($Skip -or $Node.Name -eq 'h1') { continue }
          $ReleaseNotesNodes.Add($Node)
        }

        $ReleaseNotes = $ReleaseNotesNodes | Get-TextContent | Format-Text
        if ([string]::IsNullOrWhiteSpace($ReleaseNotes)) {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        } else {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotes
          }
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
