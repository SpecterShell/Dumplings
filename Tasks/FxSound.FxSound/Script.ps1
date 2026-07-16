$Object1 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/fxsound2/fxsound-app/HEAD/release/updates.txt' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.Update.ProductVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://raw.githubusercontent.com/fxsound2/fxsound-app/refs/tags/v$($this.CurrentState.Version)/release/fxsound_setup.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://raw.githubusercontent.com/fxsound2/fxsound-app/refs/tags/v$($this.CurrentState.Version)/release/arm64/fxsound_setup.arm64.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/fxsound2/fxsound-app/HEAD/release/changelog.txt').RawContentStream)

      while (-not $Object2.EndOfStream) {
        if ($Object2.ReadLine() -match "version $([regex]::Escape($this.CurrentState.Version))") {
          $null = $Object2.ReadLine()
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if ($String -notmatch '^version \d+(?:\.\d+)+') {
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
