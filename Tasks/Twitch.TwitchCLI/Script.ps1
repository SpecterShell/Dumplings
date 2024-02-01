$RepoOwner = 'twitchdev'
$RepoName = 'twitch-cli'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('Windows') -and $_.name.Contains('i386') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerUrl         = $Asset.browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath     = "$($Asset.name | Split-Path -LeafBase)\twitch.exe"
      PortableCommandAlias = 'twitch'
    }
  )
}
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('Windows') -and $_.name.Contains('x86_64') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = $Asset.browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath     = "$($Asset.name | Split-Path -LeafBase)\twitch.exe"
      PortableCommandAlias = 'twitch'
    }
  )
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
  $ReleaseNotesObject = ($Object1.body | ConvertFrom-Markdown).Html | ConvertFrom-Html
  $ReleaseNotesNodes = [System.Collections.Generic.List[System.Object]]::new()
  for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and -not ($Node.Name -eq 'h2' -and $Node.InnerText.Contains('Changelog')); $Node = $Node.NextSibling) {
    $ReleaseNotesNodes.Add($Node)
  }
  if ($ReleaseNotesNodes) {
    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
    }
  } else {
    $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
  }
} else {
  $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $Object1.html_url
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
