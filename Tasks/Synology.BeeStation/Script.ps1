$Object1 = Invoke-RestMethod -Uri 'https://utyautoupdate.synology.com/getUpdate/BeeStationClient?os=windows&bits=64&include_beta=false' | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.path
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.synology.com/api/releaseNote/findChangeLog?identify=BeeStationClient&lang=en-us' | Read-ResponseContent | ConvertFrom-Json -AsHashtable

      $ReleaseNotesObject = $Object2.info.versions.''.all_versions.Where({ ($_.version -replace '-0(\d{3})$', '-$1') -eq $this.CurrentState.Version }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= $ReleaseNotesObject[0].publish_date | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject[0].content | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object4 = (Invoke-WebRequest -Uri 'https://www.synology.com/api/releaseNote/findChangeLog?identify=BeeStationClient&lang=zh-cn').Content | ConvertFrom-Json -AsHashtable

      $ReleaseNotesCNObject = $Object4.info.versions.''.all_versions.Where({ ($_.version -replace '-0(\d{3})$', '-$1') -eq $this.CurrentState.Version }, 'First')
      if ($ReleaseNotesCNObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= $ReleaseNotesCNObject[0].publish_date | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNObject[0].content | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
