$RepoOwner = 'mixxxdj'
$RepoName = 'mixxx'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

$Object2 = Invoke-RestMethod -Uri "https://downloads.mixxx.org/releases/$($this.CurrentState.Version)/manifest.json"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.'windows-win64'.file_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.'windows-win64'.file_date.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://mixxx.org/news/'
      }

      $Object3 = (Invoke-RestMethod -Uri 'https://mixxx.org/feed.xml').Where({ $_.title.Contains("Mixxx $($this.CurrentState.Version)") }, 'First')

      if ($Object3) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3[0].content.'#text' | ConvertFrom-Html | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object3[0].link.href
        }
      } else {
        $Object4 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/mixxxdj/mixxx/HEAD/CHANGELOG.md' | Convert-MarkdownToHtml

        $ReleaseNotesTitleNode = $Object4.SelectSingleNode("/h2[contains(., '$($this.CurrentState.Version)')]")
        if ($ReleaseNotesTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }

          # ReleaseNotesUrl
          $this.CurrentState.Locale += [ordered]@{
            Key   = 'ReleaseNotesUrl'
            Value = 'https://github.com/mixxxdj/mixxx/blob/HEAD/CHANGELOG.md#' + ($ReleaseNotesTitleNode.InnerText -creplace '[^a-zA-Z0-9\-\s]+', '' -creplace '\s+', '-').ToLower()
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
        }
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
