$Object1 = (Invoke-RestMethod -Uri 'https://www.password-depot.de/download/pdepot19.info').versioninfo.version.Where({ $_.edition -eq 'CORPORATE' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.number

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri 'https://www.password-depot.de/download/' $Object1.setupfile
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.password-depot.de/en/resources/whats-new.htm' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@id='content-windows']//h3[contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
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
