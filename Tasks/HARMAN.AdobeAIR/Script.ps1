$Object1 = (Invoke-RestMethod -Uri 'https://airsdk.harman.com/api/versions/release-notes').Where({ $_.latest -eq $true })[0]

# Version
$this.CurrentState.Version = $Object1.versionName

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://airsdk.harman.com/assets/downloads/AdobeAIR.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releasedDate | ConvertFrom-UnixTimeMilliseconds

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.releaseNotes | ForEach-Object -Process { "$($_.title): $($_.description)" } | Format-Text
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
