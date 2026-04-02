$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/bromagosa/Snap4Arduino/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerType        = 'zip'
  NestedInstallerType  = 'inno'
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "Snap4Arduino-$($this.CurrentState.Version)-32.exe"
    }
  )
  InstallerUrl         = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('-32') -and $_.name.Contains('installer') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'inno'
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "Snap4Arduino-$($this.CurrentState.Version)-64.exe"
    }
  )
  InstallerUrl         = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('-64') -and $_.name.Contains('installer') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
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
