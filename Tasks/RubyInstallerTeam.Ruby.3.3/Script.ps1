$Object1 = $Global:DumplingsStorage.RubyGitHubReleases.Where({ $_.tag_name.StartsWith('RubyInstaller-3.3.') }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^RubyInstaller-'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x86'
  InstallerUrl           = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and -not $_.name.Contains('devkit') -and $_.name.Contains('x86') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName = "Ruby $($this.CurrentState.Version)-x86"
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x64'
  InstallerUrl           = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and -not $_.name.Contains('devkit') -and $_.name.Contains('x64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName = "Ruby $($this.CurrentState.Version)-x64"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

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
