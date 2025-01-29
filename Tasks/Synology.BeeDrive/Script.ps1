$Object1 = Invoke-RestMethod -Uri 'https://utyautoupdate.synology.com/getUpdate/BeeDrive?os=windows&bits=64&include_beta=false'

# Version
$this.CurrentState.Version = "$($Object1.version.major).$($Object1.version.minor).$($Object1.version.hotfix)-$($Object1.version.build_number)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.installer.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.release_date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.synology.com/api/releaseNote/findChangeLog?identify=BeeDrive&lang=en-us' | Read-ResponseContent | ConvertFrom-Json -AsHashtable

      $ReleaseNotesObject = $Object2.info.versions.''.all_versions.Where({ $_.version -eq $this.CurrentState.Version }, 'First')
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
