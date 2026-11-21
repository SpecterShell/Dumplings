$Object1 = Invoke-RestMethod -Uri 'https://app.hubstaff.com/appcast/release.xml?platform=Windows'

# Version
$this.CurrentState.Version = $Object1.enclosure.version

# RealVersion
$this.CurrentState.RealVersion = [regex]::Match($this.CurrentState.Version, '^(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.enclosure.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.pubDate | Get-Date -AsUTC

      $ReleaseNotesObject = $Object1.description.'#cdata-section' | ConvertFrom-Html
      $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.RealVersion)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
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
