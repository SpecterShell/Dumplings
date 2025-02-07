$Object1 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://update.microsip.org/softphone-update.txt').RawContentStream)

# Version
$null = $Object1.ReadLine()
$this.CurrentState.Version = $Object1.ReadLine()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://www.microsip.org/download/MicroSIP-$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      while (-not $Object1.EndOfStream) {
        $String = $Object1.ReadLine()
        if ($String.StartsWith($this.CurrentState.Version)) {
          break
        }
      }
      if (-not $Object1.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object1.EndOfStream) {
          $String = $Object1.ReadLine()
          if ($String -notmatch '^\d+(?:\.\d+){2,}') {
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

    try {
      $Object1.Close()
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
