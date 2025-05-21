$Object1 = ((Invoke-WebRequest -Uri 'https://www.gimp.org/gimp_versions.json').Content | ConvertFrom-Json -AsHashtable).STABLE.Where({ $_.version.StartsWith('3.') }, 'First')[0]

# Version
$this.CurrentState.Version = "$($Object1.version).$($Object1.windows[0].Contains('revision') ? $Object1.windows[0].revision : '0')"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri 'https://download.gimp.org/gimp/v3.0/windows/' $Object1.windows[0].filename
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.windows[0].date | Get-Date -Format 'yyyy-MM-dd'

      if ($Object1.windows[0].Contains('comment')) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object1.windows[0].comment | Format-Text
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
