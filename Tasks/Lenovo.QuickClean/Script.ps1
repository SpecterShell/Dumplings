$Object1 = Invoke-WebRequest -Uri 'https://support.lenovo.com/us/en/downloads/ds540666' -Headers @{
  'Accept'          = 'text/html'
  'Accept-Language' = 'en-US'
} -UserAgent $DumplingsBrowserUserAgent
$Object2 = $Object1.Content | Get-EmbeddedJson -StartsFrom 'window.customData || ' | ConvertFrom-Json
$Object3 = $Object2.driver.body.DriverDetails.Files.Where({ $_.URL.EndsWith('.exe') })[0]

# Version
$this.CurrentState.Version = $Object3.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object3.URL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.Date.Unix | ConvertFrom-UnixTimeMilliseconds
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      $Object4 = $Object2.driver.body.DriverDetails.Files.Where({ $_.URL.EndsWith('.txt') })[0]

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Object4.URL
      }

      $Object5 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri $ReleaseNotesUrl).RawContentStream)
      while (-not $Object5.EndOfStream) {
        if ($Object5.ReadLine() -match 'CHANGES IN THIS RELEASE') {
          $null = $Object5.ReadLine() # Skip the header
          break
        }
      }
      if (-not $Object5.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object5.EndOfStream) {
          $String = $Object5.ReadLine()
          if ($String -notmatch '^-+$') {
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
