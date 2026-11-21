

$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/MSEndpointMgr/IntuneDebugToolkit/contents/'
$Path = $Object1.Where({ $_.name.EndsWith('.msi') }, 'First')[0].path

$Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/MSEndpointMgr/IntuneDebugToolkit/commits?path=${Path}"

# Version
$this.CurrentState.Version = [regex]::Match($Path, '(\d+(\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://raw.githubusercontent.com/MSEndpointMgr/IntuneDebugToolkit/$($Object2[0].sha)/${Path}"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'https://github.com/MSEndpointMgr/IntuneDebugToolkit/blob/HEAD/README.md'
      }

      $Object2 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/MSEndpointMgr/IntuneDebugToolkit/HEAD/README.md' | Convert-MarkdownToHtml

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h3[contains(text(), '$($this.CurrentState.Version.Split('.')[0..1] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        if ($ReleaseNotesTitleNode.InnerText -match '(\d{1,2}-\d{1,2}-20\d{2})') {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Matches[1], 'dd-MM-yyyy', $null).ToString('yyyy-MM-dd')
        }

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl + '#' + ($ReleaseNotesTitleNode.InnerText -replace '[^a-zA-Z0-9\-\s]+', '' -replace '\s+', '-').ToLower()
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
