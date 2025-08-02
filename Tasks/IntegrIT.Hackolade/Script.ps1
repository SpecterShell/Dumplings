$Object1 = (Invoke-WebRequest -Uri 'https://hackolade.com/versionInfo/versioninfo.json').Content | ConvertFrom-Json -AsHashtable

# Version
$this.CurrentState.Version = ($Object1.versions.GetEnumerator() | Sort-Object -Property { [RawVersion]$_.Key } -Bottom 1).Value.Where({ $_.os -eq 'windows' }, 'First')[0].version[@('major', 'minor', 'revisionNumber')] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://s3-eu-west-1.amazonaws.com/hackolade/previous/v$($this.CurrentState.Version)/Hackolade-win64-setup-signed.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://hackolade.com/versionInfo/ReadMe.txt').RawContentStream)

      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String -match "^New features in v$([regex]::Escape($this.CurrentState.Version))") {
          if ($String -match '(\d{1,2}-[a-zA-Z]+-20\d{2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
          } else {
            $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          }
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if ($String -notmatch '^New features in v\d+(\.\d+)+') {
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
