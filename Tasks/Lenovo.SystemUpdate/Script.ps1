$Object1 = Invoke-WebRequest -Uri 'https://support.lenovo.com/us/en/downloads/ds012808' -Headers @{
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
      $Object4 = $Object2.driver.body.DriverDetails.Files.Where({ $_.URL.EndsWith('.txt') })[0]

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object4.URL
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }
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
