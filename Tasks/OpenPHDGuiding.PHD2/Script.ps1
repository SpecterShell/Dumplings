$Object1 = (Invoke-RestMethod -Uri 'https://openphdguiding.org/release-main-win.txt').Split()

# Version
$this.CurrentState.Version = $Object1[0].Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1[1].Trim()
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://openphdguiding.org/changelog-main/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::text()[1]')
        if ($ReleaseTimeNode -and $ReleaseTimeNode.InnerText -match '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})') {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'

          $ReleaseNotesNodes = for ($Node = $ReleaseTimeNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
        } else {
          $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')

          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node) { $Node }
        }
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
