$RepoOwner = 'Xmarmalade'
$RepoName = 'alisthelper'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('windows') -and $_.name.Contains('x86_64') -and $_.name.Contains('installer') })[0].browser_download_url | ConvertTo-UnescapedUri
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
  $ReleaseNotesObject = ($Object1.body | ConvertFrom-Markdown).Html | ConvertFrom-Html
  $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("./h4[contains(text(), `"What's New`")]")
  if ($ReleaseNotesTitleNode) {
    $ReleaseNotesNodes = [System.Collections.Generic.List[System.Object]]::new()
    for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.InnerText.Contains('Full Changelog:'); $Node = $Node.NextSibling) {
      $ReleaseNotesNodes.Add($Node)
    }
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
