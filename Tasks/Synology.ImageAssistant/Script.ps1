$Prefix = 'https://utyautoupdate.synology.com/getUpdate/SynologyImageAssistant?os=Windows&include_beta=false&version=2'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'en-US'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object1 = Invoke-WebRequest -Uri 'https://www.synology.com/api/releaseNote/findChangeLog?identify=SynologyImageAssistant&lang=en-us' | Read-ResponseContent | ConvertFrom-Json -AsHashtable

      $ReleaseNotesObject = $Object1.info.versions.''.all_versions.Where({ $_.version -eq $this.CurrentState.Version }, 'First')
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
      $Object2 = Invoke-WebRequest -Uri 'https://www.synology.com/api/releaseNote/findChangeLog?identify=SynologyImageAssistant&lang=zh-cn' | Read-ResponseContent | ConvertFrom-Json -AsHashtable

      $ReleaseNotesCNObject = $Object2.info.versions.''.all_versions.Where({ $_.version -eq $this.CurrentState.Version }, 'First')
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
