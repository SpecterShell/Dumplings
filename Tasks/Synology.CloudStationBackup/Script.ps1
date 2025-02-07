# x86
$Object1 = Invoke-RestMethod -Uri 'https://utyautoupdate.synology.com/getUpdate/CloudStationBackup?os=windows&bits=32&include_beta=false'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.installer.url, '(\d+\.\d+\.\d+-\d+)').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version -replace '-', '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'nullsoft'
  InstallerUrl  = 'https:' + $Object1.installer.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'msi'
  InstallerUrl  = 'https:' + $Object1.installer.url -replace '\.exe$', '.msi'
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
      $Object2 = (Invoke-WebRequest -Uri 'https://www.synology.com/api/releaseNote/findChangeLog?identify=CloudStationBackup&lang=en-us').Content | ConvertFrom-Json -AsHashtable

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
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
