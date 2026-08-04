$Object1 = Invoke-RestMethod -Uri 'https://portal.broadcastradio.com/updates/apps/45786b15-ded8-4657-a7dc-c0bc195aa985?track=full'
if ($Object1 -isnot [System.Array]) { $Object1 = , $Object1 }

# Version
$this.CurrentState.Version = $Object1[0].enclosure.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1[0].enclosure.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1[0].pubDate | Get-Date -AsUTC

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Object1[0].releaseNotesLink
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = (Invoke-WebRequest -Uri $ReleaseNotesUrl).RawContentStream | Read-ResponseContent | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(text(), '$($Object1[0].title.'#cdata-section')')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -notin @('h1', 'h2'); $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
