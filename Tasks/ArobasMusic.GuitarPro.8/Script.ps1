$Object1 = Invoke-RestMethod -Uri 'https://updates.guitar-pro.com/gp8?os=Windows&channel=stable'

# Version
$this.CurrentState.Version = $Object1.enclosure.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.enclosure.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        $Object1.pubDate,
        [string[]]@(
          'ddd MMM d HH:mm:ss RDT yyyy'
          'ddd MMM d HH:mm:ss RST yyyy'
        ),
        (Get-Culture -Name 'en-US')
      ) | ConvertTo-UtcDateTime -Id 'Romance Standard Time'

      $Object2 = $Object1.description.'#cdata-section' | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@class='markdown-body']/h3[@id='section' and contains(text(), '$($this.CurrentState.Version.Split('-')[0])')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
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
