$Object1 = Invoke-RestMethod -Uri 'https://brightsign-builds.s3.us-east-1.amazonaws.com/web/bs-download-versions.json'

# Version
$this.CurrentState.Version = $Object1.general.bac.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.general.bac.link
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.general.bac.'release-date' | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.general.bac.'release-notes'
      }

      $Object2 = (Invoke-RestMethod -Uri 'https://docs.brightsign.biz/api/v2/pages/1593245719?body-format=view').body.view.value | ConvertFrom-Html
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
          if (-not $Node.InnerText.Contains('Download:')) {
            $Node
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
