$Object1 = (Invoke-GitHubApi -Uri 'https://api.github.com/repos/OpenAEC-Foundation/open-energy-studio/releases?per_page=30').Where({ -not $_.draft }, 'First')

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'
# The MSI ProductVersion drops the century prefix of the release version (2026.45.0 -> 26.45.0)
$this.CurrentState.RealVersion = $this.CurrentState.Version -replace '^(20)(\d{2}\..*)$', '$2'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('msi') -and $_.name.Contains('x64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        # ReleaseNotes (en-GB)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-GB'
          Key    = 'ReleaseNotes'
          Value  = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
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
