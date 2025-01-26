$Object1 = Invoke-RestMethod -Uri 'https://utyautoupdate.synology.com/getUpdate/NoteStationClient?os=windows&bits=64'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://global.download.synology.com/download/Utility/NoteStationClient/$($this.CurrentState.Version)/Windows/i686/synology-note-station-client-$($this.CurrentState.Version)-win-x86-Setup.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://global.download.synology.com/download/Utility/NoteStationClient/$($this.CurrentState.Version)/Windows/x86_64/synology-note-station-client-$($this.CurrentState.Version)-win-x64-Setup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.synology.com/api/releaseNote/findChangeLog?identify=NoteStationClient&lang=en-us' | Read-ResponseContent | ConvertFrom-Json -AsHashtable

      $ReleaseNotesObject = $Object2.info.versions.''.all_versions.Where({ $_.version -eq $this.CurrentState.Version }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesObject[0].publish_date | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject[0].content | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.synology.com/api/releaseNote/findChangeLog?identify=NoteStationClient&lang=zh-cn' | Read-ResponseContent | ConvertFrom-Json -AsHashtable

      $ReleaseNotesCNObject = $Object3.info.versions.''.all_versions.Where({ $_.version -eq $this.CurrentState.Version }, 'First')
      if ($ReleaseNotesCNObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesCNObject[0].publish_date | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNObject[0].content | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
