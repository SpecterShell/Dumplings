$Object1 = Invoke-RestMethod -Uri 'https://files.kotobee.com/author/releases/releases.json'
$Release = $Object1.releases[-1]

# Version
$this.CurrentState.Version = $Release.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://files.kotobee.com/author/releases/kotobeeauthor-$($this.CurrentState.Version)-win32.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://files.kotobee.com/author/releases/kotobeeauthor-$($this.CurrentState.Version)-win64.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Release.date | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      if (-not [string]::IsNullOrWhiteSpace($Release.notes)) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $Release.notes
        }
      }

      if (-not [string]::IsNullOrWhiteSpace($Release.description)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Release.description
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
