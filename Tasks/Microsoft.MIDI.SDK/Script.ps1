$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/microsoft/MIDI/releases?per_page=30'
# Select the latest release that carries the SDK Runtime and Tools installer assets
$Object1 = @($Object1).Where({ $_.assets.Where({ $_.name.Contains('Windows.MIDI.Services.SDK.Runtime.and.Tools') -and $_.name.EndsWith('-x64.exe') }) }, 'First')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'burn'
  InstallerUrl  = $Object1.assets.Where({ $_.name.Contains('Windows.MIDI.Services.SDK.Runtime.and.Tools') -and $_.name.EndsWith('.exe') -and $_.name.Contains('x64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'burn'
  InstallerUrl  = $Object1.assets.Where({ $_.name.Contains('Windows.MIDI.Services.SDK.Runtime.and.Tools') -and $_.name.EndsWith('.exe') -and $_.name.Contains('arm64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

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
