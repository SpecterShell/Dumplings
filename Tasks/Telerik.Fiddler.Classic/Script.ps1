$Object1 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://api.getfiddler.com/fc/latest?meta=true').RawContentStream)

# Version
$this.CurrentState.Version = (0..3 | ForEach-Object -Process { $Object1.ReadLine() }) -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl1st -Uri 'https://api.getfiddler.com/fc/latest?meta=false'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # ReleaseNotesUrl
    $this.CurrentState.Locale += [ordered]@{
      Key   = 'ReleaseNotesUrl'
      Value = "https://www.telerik.com/support/whats-new/fiddler/release-history/fiddler-v$($this.CurrentState.Version.Split('.')[0..2] -join '.')"
    }

    try {
      while (-not $Object1.EndOfStream) {
        $String = $Object1.ReadLine()
        if ($String.StartsWith($this.CurrentState.Version)) {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
            [regex]::Match($String, '\[(\d{1,2}/\d{1,2}/\d{4})\]').Groups[1].Value,
            'dd/MM/yyyy',
            $null
          ).ToString('yyyy-MM-dd')

          break
        }
      }
      if (-not $Object1.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object1.EndOfStream) {
          $String = $Object1.ReadLine()
          if ($String -notmatch '^\d+\.\d+\.\d+\.\d+') {
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
