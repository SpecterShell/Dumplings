$Prefix = 'https://releases.hashicorp.com/boundary/'
$Object1 = Invoke-WebRequest -Uri $Prefix

$FolderName = $Object1.Links.Where({ try { $_.href -match '^/boundary/\d+(?:\.\d+)+/$' } catch {} }).href | Sort-Object -Property { $_ -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = [regex]::Match($FolderName, '(\d+(?:\.\d+)+)').Groups[1].Value

$Prefix = Join-Uri $Prefix $FolderName
$Object2 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'zip'
  InstallerUrl  = Join-Uri $Prefix $Object2.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('windows') -and $_.href.Contains('_386') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'zip'
  InstallerUrl  = Join-Uri $Prefix $Object2.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('windows') -and $_.href.Contains('amd64') } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $RepoOwner = 'hashicorp'
      $RepoName = 'boundary'

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://github.com/${RepoOwner}/${RepoName}/releases"
      }

      $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/tags/v$($this.CurrentState.Version)"

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object2.body)) {
        $ReleaseNotesObject = $Object2.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("./h2[contains(text(), '$($this.CurrentState.Version)')]")
        if ($ReleaseNotesTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
          }
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object2.html_url
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
