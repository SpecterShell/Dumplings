# Version
$this.CurrentState.Version = $Global:DumplingsStorage.SyncROSoftApps.checkVersion.builds.currentVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://archives.oxygenxml.com/Oxygen/Editor/InstData$($this.CurrentState.Version)/Windows64/VM/oxygen-64bit-openjdk.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.SyncROSoftApps.GetElementsByTagName('build')[0].pubDate | Get-Date -AsUTC

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Global:DumplingsStorage.SyncROSoftApps.GetElementsByTagName('build')[0].description | Where-Object -FilterScript { $_.platform -split ', ' -contains 'Windows' -and $_.product -split ', ' -contains 'Editor' } | Select-Object -ExpandProperty '#text' | Join-String -Separator "`n" | ConvertFrom-Html | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = "https://www.oxygenxml.com/xml_editor/whatisnew$($this.CurrentState.Version).html"
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
