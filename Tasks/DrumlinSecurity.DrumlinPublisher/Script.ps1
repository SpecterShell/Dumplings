$Prefix = 'https://www.drumlinsecurity.com/publisherdownloads.php'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.drumlinsecurity.com/releasenotes.php' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h4[contains(text(), 'Drumlin Publisher') and (contains(text(), '$($this.CurrentState.Version)') or contains(text(), '$('{0}.{1}.{2}{3}' -f $this.CurrentState.Version.Split('.'))'))]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Matches($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}[a-zA-Z]+\W+20\d{2})')[-1].Groups[1].Value,
          [string[]]@(
            "MMMM d'st' yyyy", "MMM d'st' yyyy",
            "MMMM d'nd' yyyy", "MMM d'nd' yyyy",
            "MMMM d'rd' yyyy", "MMM d'rd' yyyy",
            "MMMM d'th' yyyy", "MMM d'th' yyyy"
          ),
          (Get-Culture -Name 'en-US'),
          [System.Globalization.DateTimeStyles]::None
        ).ToString('yyyy-MM-dd')

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h4'; $Node = $Node.NextSibling) { $Node }
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
