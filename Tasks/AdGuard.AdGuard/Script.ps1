$Object1 = Invoke-RestMethod -Uri 'https://api.adguard.org/api/2.0/checkupdate.html?app_id=64dbc91754f34b0ebcc6eecadf83eb81&channel=Release&appname=adguard_ru&version=7.0.0.0&force=1&os_version=10.0.22000.0'

# Version
$this.CurrentState.Version = $Object1.response.version.'#cdata-section'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.response.'update-url'.'#cdata-section'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesTitleNode = ($Object1.response.'release-notes'.'#cdata-section' | Convert-MarkdownToHtml).SelectSingleNode("./h1[text()='$($this.CurrentState.Version)']")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h1'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.response.'more-info-url'.'#cdata-section'
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
