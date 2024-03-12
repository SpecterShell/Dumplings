$RepoOwner = 'rust-lang'
$RepoName = 'rustfmt'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('windows') -and $_.name.Contains('x86_64') -and $_.name.Contains('gnu') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = $Asset.browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath     = "$($Asset.name | Split-Path -LeafBase)\cargo-fmt.exe"
      PortableCommandAlias = 'cargo-fmt'
    }
    [ordered]@{
      RelativeFilePath     = "$($Asset.name | Split-Path -LeafBase)\git-rustfmt.exe"
      PortableCommandAlias = 'git-rustfmt'
    }
    [ordered]@{
      RelativeFilePath     = "$($Asset.name | Split-Path -LeafBase)\rustfmt.exe"
      PortableCommandAlias = 'rustfmt'
    }
    [ordered]@{
      RelativeFilePath     = "$($Asset.name | Split-Path -LeafBase)\rustfmt-format-diff.exe"
      PortableCommandAlias = 'rustfmt-format-diff'
    }
  )
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = ($Object1.body | ConvertFrom-Markdown).Html | ConvertFrom-Html | Get-TextContent | Format-Text
  }
} else {
  $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $Object1.html_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
