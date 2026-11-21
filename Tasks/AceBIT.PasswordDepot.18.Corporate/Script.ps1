$Object1 = (Invoke-RestMethod -Uri 'https://www.password-depot.de/download/pdepot18.info').versioninfo.version.Where({ $_.edition -eq 'CORPORATE' }, 'First')[0]

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

      $ReleaseNotesNode = $Object2.SelectSingleNode("//details[@class='vh-release' and contains(./summary[@class='vh-release-summary'], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//div[@class="vh-release-body"]') | Get-TextContent | Format-Text
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
