$RepoOwner = 'tiny-craft'
$RepoName = 'tiny-rdm'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('windows') -and $_.name.Contains('amd64') -and $_.name.Contains('Setup') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Asset.browser_download_url | ConvertTo-UnescapedUri
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
  $ReleaseNotesObject = ($Object1.body | ConvertFrom-Markdown).Html | ConvertFrom-Html

  $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and $Node.Name -ne 'hr'; $Node = $Node.NextSibling) { $Node }
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

  $ReleaseNotesCNTitleNode = $ReleaseNotesObject.SelectSingleNode('./hr[1]')
  if ($ReleaseNotesCNTitleNode) {
    $ReleaseNotesNodes = for ($Node = $ReleaseNotesCNTitleNode.NextSibling; $Node -and $Node.Name -ne 'hr'; $Node = $Node.NextSibling) { $Node }
    # ReleaseNotes (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
    }
  } else {
    $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
  }
} else {
  $this.Log("No ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
