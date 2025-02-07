$RepoOwner = 'zaps166'
$RepoName = 'QMPlay2'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('Win32') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('Win64') -and -not $_.name.Contains('qt5') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions $MarkdigSoftlineBreakAsHardlineExtension
        $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("./p[contains(.//text(), 'Changes in QMPlay2')]")
        if ($ReleaseNotesTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'hr'; $Node = $Node.NextSibling) { $Node }
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
