$Object1 = (Invoke-WebRequest -Uri 'https://update.openmpt.org/api/v3/update/release' | Read-ResponseContent | ConvertFrom-Json -AsHashtable).GetEnumerator() | Sort-Object -Property { $_ -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1 | Select-Object -ExpandProperty 'Value'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.downloads.installer.download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.date.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $Object1.changelog_url
      }

      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri $ReleaseNotesUrl).RawContentStream)

      while (-not $Object2.EndOfStream) {
        if ($Object2.ReadLine() -match "^v$([regex]::Escape($this.CurrentState.Version))") {
          $null = $Object2.ReadLine()
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if ($String -notmatch '^v\d+(?:\.\d+)+') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
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
