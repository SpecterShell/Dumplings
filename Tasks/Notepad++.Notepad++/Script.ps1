$RepoOwner = 'notepad-plus-plus'
$RepoName = 'notepad-plus-plus'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('Installer') -and $_.name -notmatch 'x64|arm64' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msi'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.msi') -and $_.name.Contains('Installer') -and $_.name.Contains('x64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('Installer') -and $_.name.Contains('x64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('Installer') -and $_.name.Contains('arm64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x86'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('portable') -and $_.name -notmatch 'x64|arm64' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('portable') -and $_.name.Contains('x64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'arm64'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('portable') -and $_.name.Contains('arm64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      # if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
      #   # ReleaseNotes (en-US)
      #   $this.CurrentState.Locale += [ordered]@{
      #     Locale = 'en-US'
      #     Key    = 'ReleaseNotes'
      #     Value  = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
      #   }
      # } else {
      #   $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      # }

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
