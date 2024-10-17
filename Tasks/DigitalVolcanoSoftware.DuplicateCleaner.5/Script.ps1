$Object1 = Invoke-WebRequest -Uri 'https://www.digitalvolcano.co.uk/download/dcp5_version.txt'

# Version
$this.CurrentState.Version = $Object1.Content.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.digitalvolcano.co.uk/download/DuplicateCleaner-Setup-5.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.digitalvolcano.co.uk/dcchangelog.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h4[contains(text(), 'v$($this.CurrentState.Version -replace '\.0$')')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match(
            $ReleaseNotesTitleNode.InnerText,
            '(\d{1,2}(?:st|nd|rd|th)\s+[a-zA-Z]+\s+\d{4})'
          ).Groups[1].Value,
          [string[]]@(
            "d'st' MMM yyyy", "d'st' MMMM yyyy",
            "d'nd' MMM yyyy", "d'nd' MMMM yyyy",
            "d'rd' MMM yyyy", "d'rd' MMMM yyyy",
            "d'th' MMM yyyy", "d'th' MMMM yyyy"
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
