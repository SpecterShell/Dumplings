$RepoOwner = 'team-ide'
$RepoName = 'teamide'

$Object1 = Invoke-RestMethod -Uri "https://github.com/${RepoOwner}/${RepoName}/releases/latest/download/latest.yml" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

$Prefix = "https://github.com/${RepoOwner}/${RepoName}/releases/download/v$($this.CurrentState.Version)/"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix + $Object1.files[0].url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = "https://github.com/${RepoOwner}/${RepoName}/releases/tag/v$($this.CurrentState.Version)"
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = (Invoke-RestMethod -Uri "https://github.com/${RepoOwner}/${RepoName}/releases.atom").Where({ $_.id.EndsWith("v$($this.CurrentState.Version)") }, 'First')[0]

      if ($Object2.content.'#text' -ne 'No content.') {
        $ReleaseNotesObject = $Object2.content.'#text' | ConvertFrom-Html
        $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode('./p[text()="发布功能"]')
        if ($ReleaseNotesTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node; $Node = $Node.NextSibling) { $Node }
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
        $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
