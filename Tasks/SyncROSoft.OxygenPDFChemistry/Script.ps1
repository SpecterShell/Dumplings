# Version
$this.CurrentState.Version = $Global:DumplingsStorage.SyncROSoftApps.checkVersion.builds.currentVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://archives.oxygenxml.com/Oxygen/Chemistry/InstData$($this.CurrentState.Version)/oxygen-pdf-chemistry.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.SyncROSoftApps.GetElementsByTagName('build')[0].pubDate | Get-Date -AsUTC

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = "https://www.oxygenxml.com/pdf_chemistry/whatisnew$($this.CurrentState.Version).html"
      }

      $Object1 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.SelectNodes('//div[@class="date"]/following-sibling::node()') | Get-TextContent | Format-Text
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
