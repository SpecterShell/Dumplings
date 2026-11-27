$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/printfapp/TextPin/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

if ($this.CurrentState.Version -notmatch '^[0-9]+(\.[0-9]+)*$') {
  throw 'The latest release tag does not provide a numeric version.'
}

# Installer
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name -match 'setup' -and $_.name -notmatch 'portable|update' }, 'First')[0]
if (-not $Asset) {
  throw 'The latest release does not provide a Windows x64 NSIS setup installer.'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Asset.browser_download_url | ConvertTo-UnescapedUri
}
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.msi') -and $_.name.Contains('x64') -and $_.name -notmatch 'debug|update' }, 'First')[0]
if (-not $Asset) {
  throw 'The latest release does not provide a Windows x64 MSI installer.'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
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

    # The release only publishes minisign .sig assets, so no SHA-256 is available to verify the downloads against.

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = [string]$Object1.html_url
      }

      if ([string]::IsNullOrWhiteSpace($Object1.body)) {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      } else {
        # The body is English only, and everything from "## Downloads" onwards is asset listings and
        # first-run SmartScreen, Gatekeeper, and chmod guidance rather than product changes.
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
