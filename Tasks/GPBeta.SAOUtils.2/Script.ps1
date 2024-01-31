$RepoOwner = 'NERvGear'
$RepoName = 'SAO-Utils'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('setup') })[0].browser_download_url | ConvertTo-UnescapedUri
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
  $ReleaseNotesObject = ($Object1.body | ConvertFrom-Markdown).Html | ConvertFrom-Html

  $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("./*[text()='Change Log']")
  if ($ReleaseNotesTitleNode) {
    $ReleaseNotesNodes = [System.Collections.Generic.List[System.Object]]::new()
    for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.Name.Contains('变更日志'); $Node = $Node.NextSibling) {
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

  $ReleaseNotesCNTitleNode = $ReleaseNotesObject.SelectSingleNode("./*[text()='变更日志']")
  if ($ReleaseNotesCNTitleNode) {
    $ReleaseNotesNodes = [System.Collections.Generic.List[System.Object]]::new()
    for ($Node = $ReleaseNotesCNTitleNode.NextSibling; $Node; $Node = $Node.NextSibling) {
      $ReleaseNotesNodes.Add($Node)
    }
    # ReleaseNotes (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
    }
  } else {
    $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
  }
} else {
  $this.Logging("No ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
