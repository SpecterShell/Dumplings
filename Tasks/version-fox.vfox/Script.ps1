$RepoOwner = 'version-fox'
$RepoName = 'vfox'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'inno'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('i386') -and $_.name.Contains('setup') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x86_64') -and $_.name.Contains('setup') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'inno'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('aarch64') -and $_.name.Contains('setup') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('i386') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerType        = 'zip'
  InstallerUrl         = $Asset.browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath     = "$($Asset.name | Split-Path -LeafBase)\vfox.exe"
      PortableCommandAlias = 'vfox'
    }
  )
}
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('x86_64') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  InstallerUrl         = $Asset.browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath     = "$($Asset.name | Split-Path -LeafBase)\vfox.exe"
      PortableCommandAlias = 'vfox'
    }
  )
}
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('aarch64') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'arm64'
  InstallerType        = 'zip'
  InstallerUrl         = $Asset.browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath     = "$($Asset.name | Split-Path -LeafBase)\vfox.exe"
      PortableCommandAlias = 'vfox'
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

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.html_url
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
