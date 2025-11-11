$Object1 = (Invoke-RestMethod -Uri 'https://www.password-depot.de/download/pdepot18.info').versioninfo.version.Where({ $_.edition -eq 'STANDARD' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.number

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri 'https://www.password-depot.de/download/v18/' $Object1.setupfile
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.password-depot.de/en/resources/whats-new.htm' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@id='tabs-1']//h2[contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
      # ReleaseTime
      if ($ReleaseNotesTitleNode.InnerText -match '(\d{1,2}\.\d{1,2}\.20\d{2})') {
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Matches[1], 'dd.MM.yyyy', $null).ToString('yyyy-MM-dd')
      } elseif ($ReleaseNotesTitleNode.InnerText -match '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})') {
        $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
      }

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
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
