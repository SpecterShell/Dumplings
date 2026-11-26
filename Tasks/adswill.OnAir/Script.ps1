$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/adswill/OnAir/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name -match 'setup' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        # Each release lists every platform file under a "Downloads" heading before the changes.
        $ReleaseNotesDocument = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis'
        $Skip = $false
        $SkippedHeadingLevel = 0
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesDocument.ChildNodes[0]; $Node; $Node = $Node.NextSibling) {
          if ($Node.Name -match '^h([1-6])$') {
            $HeadingLevel = [int]$Matches[1]
            if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
              $Skip = $Node.InnerText -match '(?i)^\s*(Downloads?|Hash(?:es)?|Checksums?|SHA-256|下载|校验和)\s*$'
              if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
            }
          }
          if (-not $Skip) { $Node }
        }

        # ReleaseNotes (en-GB)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-GB'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-GB) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl (en-GB)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-GB'
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
