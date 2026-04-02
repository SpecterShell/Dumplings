# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Global:DumplingsStorage.ASAPUtilitiesDownloadPage.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('HS') } catch {} }, 'First')[0].href.Replace('server2.asap-utilities.com', 'server1.asap-utilities.com')
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:-\d+)+)').Groups[1].Value.Replace('-', '.')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://www.asap-utilities.com/rss.php').Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object2) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].description.'#cdata-section' | ConvertFrom-Html | Get-TextContent | Format-Text
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
