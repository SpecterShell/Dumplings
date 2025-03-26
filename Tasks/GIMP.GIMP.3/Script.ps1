$Object1 = (Invoke-WebRequest -Uri 'https://www.gimp.org/gimp_versions.json').Content | ConvertFrom-Json -AsHashtable

# Version
$this.CurrentState.Version = $Object1.STABLE[0].version + ($Object1.STABLE[0].windows[0].Contains('revision') ? "-$($Object1.STABLE[0].windows[0].revision)" : '')

# RealVersion
$this.CurrentState.RealVersion = $Object1.STABLE[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri 'https://download.gimp.org/gimp/v3.0/windows/' $Object1.STABLE[0].windows[0].filename
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.STABLE[0].windows[0].date | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.STABLE[0].windows[0].comment | Format-Text
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
