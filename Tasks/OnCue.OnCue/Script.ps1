$Object1 = (Invoke-RestMethod -Uri 'https://download.oncuetech.com/oncue/updates-stable.json').releases.Where({ $_.platform -eq 'win-x64' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = $InstallerUrl = Join-Uri 'https://download.oncuetech.com/oncue/setup/' $Object1.filename
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = $InstallerUrl -replace '\.msi$', '.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Object1.releaseNotes -match 'Released ([a-zA-Z]+\W+\d{1,2}\W+20\d{2})') {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object1.releaseNotes -replace 'Released ([a-zA-Z]+\W+\d{1,2}\W+20\d{2})\.' | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object1.releaseNotes | Format-Text
        }
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.infoUri
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
