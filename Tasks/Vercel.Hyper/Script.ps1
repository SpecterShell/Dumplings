$RepoOwner = 'vercel'
$RepoName = 'hyper'

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

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri "https://github.com/${RepoOwner}/${RepoName}/releases.atom").Where({ $_.id.EndsWith("v$($this.CurrentState.Version)") }, 'First')[0]

      if ($Object2.content.'#text' -ne 'No content.') {
        $ReleaseNotesObject = $Object2.content.'#text' | ConvertFrom-Html
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and -not $Node.InnerText.Contains('Full Changelog:'); $Node = $Node.NextSibling) {
          if ($Node.Name -ne 'table') {
            $Node
          }
        }
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
