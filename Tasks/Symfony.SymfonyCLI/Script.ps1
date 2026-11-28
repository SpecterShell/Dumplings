$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/symfony-cli/symfony-cli/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# goreleaser ships one console executable per Windows archive, beside its LICENSE and README.
# Every asset also has a matching .sigstore.json bundle, so the extension is tested apart from the
# name prefix instead of relying on a single substring.
$Asset = $Object1.assets.Where({ $_.name.StartsWith('symfony-cli_windows_amd64') -and $_.name.EndsWith('.zip') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'portable'
  InstallerUrl         = $Asset.browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath     = 'symfony.exe'
      PortableCommandAlias = 'symfony'
    }
  )
}

$Asset = $Object1.assets.Where({ $_.name.StartsWith('symfony-cli_windows_386') -and $_.name.EndsWith('.zip') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerType        = 'zip'
  NestedInstallerType  = 'portable'
  InstallerUrl         = $Asset.browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath     = 'symfony.exe'
      PortableCommandAlias = 'symfony'
    }
  )
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
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
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
