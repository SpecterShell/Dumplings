$Object1 = Invoke-RestMethod -Uri 'https://www.pvsyst.com/download/versions/english.xml'

# Version
$this.CurrentState.Version = $Object1.releases.release[-1].version[@('major', 'minor', 'release', 'build')].'#text' -join '.'

# RealVersion
$this.CurrentState.RealVersion = $Object1.releases.release[-1].version[@('major', 'minor', 'release')].'#text' -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.releases.release[-1].url
  ProductCode  = "PVsyst $($this.CurrentState.RealVersion)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releases.release[-1].date | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.releases.release[-1].release_notes | Format-Text
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key    = 'ReleaseNotesUrl'
        Value  = "https://www.pvsyst.com/help/release-notes/index.html#$($this.CurrentState.RealVersion)"
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
