$MajorVersion = $this.Status.Contains('New') ? '4' : $this.LastState.Version.Split('.')[0]
if ((Invoke-WebRequest -Uri "https://ggnome.com/appcast/object2vr/$($MajorVersion + 1)/stable" -Method Head -MaximumRetryCount 0 -SkipHttpErrorCheck).StatusCode -eq 200) {
  $MajorVersion++
  $this.Log("The next major version ${MajorVersion} is available", 'Info')
}
$Object1 = Invoke-RestMethod -Uri "https://ggnome.com/appcast/object2vr/${MajorVersion}/stable"
$Object2 = $Object1[0].enclosure.Where({ try { $_.os -eq 'windows64' } catch {} }, 'First')[0]

# Version
$this.CurrentState.Version = $Object2.shortVersionString

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1[0].pubDate | Get-Date -AsUTC

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1[0].description.'#cdata-section' | ConvertFrom-Html | Get-TextContent | Format-Text
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
