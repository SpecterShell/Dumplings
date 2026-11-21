$Object1 = (Invoke-RestMethod -Uri 'https://downloads.pingidentity.com/pingid/desktop/updates/updates.jwt').Split('.')[1] | ConvertFrom-Base64 | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.windows64Item.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.windows64Item.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.windows64Item.pubDate | Get-Date -Format 'yyyy-MM-dd'

      $ReleaseNotesObject = $Object1.windows64Item.releaseNotes | ConvertFrom-Html
      $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
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
