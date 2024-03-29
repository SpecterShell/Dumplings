$RepoOwner = 'baulk'
$RepoName = 'baulk'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'user'
  InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Baulk') -and $_.name.EndsWith('.exe') -and $_.name.Contains('Setup') -and $_.name.Contains('x64') -and $_.name.Contains('User') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'machine'
  InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Baulk') -and $_.name.EndsWith('.exe') -and $_.name.Contains('Setup') -and $_.name.Contains('x64') -and -not $_.name.Contains('User') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  Scope        = 'user'
  InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Baulk') -and $_.name.EndsWith('.exe') -and $_.name.Contains('Setup') -and $_.name.Contains('arm64') -and $_.name.Contains('User') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  Scope        = 'machine'
  InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Baulk') -and $_.name.EndsWith('.exe') -and $_.name.Contains('Setup') -and $_.name.Contains('arm64') -and -not $_.name.Contains('User') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
  $ReleaseNotesObject = ($Object1.body | ConvertFrom-Markdown).Html | ConvertFrom-Html
  $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and -not $Node.InnerText.Contains('Full Changelog:'); $Node = $Node.NextSibling) { $Node }
  if ($ReleaseNotesNodes) {
    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
    }
  } else {
    $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
