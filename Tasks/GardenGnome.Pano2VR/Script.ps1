$MajorVersion = $this.Status.Contains('New') ? '7' : $this.LastState.Version.Split('.')[0]
if ((Invoke-WebRequest -Uri "https://ggnome.com/appcast/pano2vr/$($MajorVersion + 1)/stable" -Method Head -MaximumRetryCount 0 -SkipHttpErrorCheck).StatusCode -eq 200) {
  $MajorVersion++
  $this.Log("The next major version ${MajorVersion} is available", 'Info')
}
$Object1 = Invoke-RestMethod -Uri "https://ggnome.com/appcast/pano2vr/${MajorVersion}/stable"
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

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = New-TempFile
    curl -fsSLA $DumplingsInternetExplorerUserAgent -o $InstallerFile $this.CurrentState.Installer[0].InstallerUrl | Out-Host

    try {
      $Object3 = (curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://ggnome.com/rss.xml' | Join-String -Separator "`n" | ConvertFrom-Xml).rss.channel.item.Where({ $_.title.Contains("Pano2VR $($this.CurrentState.Version -replace '(\.0+)+$')") }, 'First')

      if ($Object3) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object3[0].link
        }
      } else {
        $this.Log("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
