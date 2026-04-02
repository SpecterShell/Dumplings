$Object1 = Invoke-RestMethod -Uri "https://updates.guitar-pro.com/gp8?os=Windows&channel=stable&version=$($this.Status.Contains('New') ? '8.1.5-26' : $this.LastState.Version)"

# Version
$this.CurrentState.Version = $Object1.enclosure.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  # InstallerUrl = $Object1.enclosure.url # New installer URL is not stable, so use the old one
  InstallerUrl = "https://downloads.guitar-pro.com/gp8/$($this.CurrentState.Version)/Windows/guitar-pro-soundbank-full.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.pubDate | Get-Date -AsUTC

      $Object2 = $Object1.description.'#cdata-section' | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.Version.Split('-')[0])')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2 | Get-TextContent | Format-Text
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
