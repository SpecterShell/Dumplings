$Object1 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://studio.download.bricklink.info/Studio2.0/version_Patch_OpenBeta.txt').RawContentStream)

while (-not $Object1.EndOfStream) {
  $String = $Object1.ReadLine()
  if ($String -match '^0 (.+)$') {
    # Version
    $this.CurrentState.Version = $Matches[1]
  } elseif ($String -match 'All-In-One Version') {
    break
  }
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://studio.download.bricklink.info/Studio2.0/Archive/$($this.CurrentState.Version)/Studio+2.0_32.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://studio.download.bricklink.info/Studio2.0/Archive/$($this.CurrentState.Version)/Studio+2.0.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $null = $Object1.BaseStream.Seek(0, 'Begin')
      while (-not $Object1.EndOfStream) {
        if ($Object1.ReadLine() -match "^0 $([regex]::Escape($this.CurrentState.Version))$") {
          $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
          while (-not $Object1.EndOfStream) {
            $String = $Object1.ReadLine()
            if ($String -match '^4 (\d+(\.\d+){2})') {
              # ReleaseTime
              $this.CurrentState.ReleaseTime = "20$($Matches[1])" | Get-Date -Format 'yyyy-MM-dd'
            } elseif ($String -match '^[1-3] (.+)$') {
              $ReleaseNotesObjects.Add($Matches[1])
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
