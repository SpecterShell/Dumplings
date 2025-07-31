# x86
$Object1 = Invoke-RestMethod -Uri 'https://utyautoupdate.synology.com/getUpdate/SynologyDriveClient?os=windows&bits=32&include_beta=false'
$VersionX86 = [regex]::Match($Object1.installer.url, '(\d+\.\d+\.\d+-\d+)').Groups[1].Value
# x64
$Object2 = Invoke-RestMethod -Uri 'https://utyautoupdate.synology.com/getUpdate/SynologyDriveClient?os=windows&bits=64&include_beta=false'
$VersionX64 = [regex]::Match($Object2.installer.url, '(\d+\.\d+\.\d+-\d+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'msi'
  InstallerUrl  = 'https:' + $Object1.installer.url -replace '\.exe$', '.msi' | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += $Installer = [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'nullsoft'
  InstallerUrl  = 'https:' + $Object1.installer.url -replace '\.msi$', '.exe' | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msi'
  InstallerUrl  = 'https:' + $Object2.installer.url -replace '\.exe$', '.msi' | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = 'https:' + $Object2.installer.url -replace '\.msi$', '.exe' | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.release_date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = ($InstallerFile | Read-ProductVersionFromExe) -replace '-', '.'

    try {
      $Object3 = (Invoke-WebRequest -Uri 'https://www.synology.com/api/releaseNote/findChangeLog?identify=SynologyDriveClient&lang=en-us').Content | ConvertFrom-Json -AsHashtable

      $ReleaseNotesObject = $Object3.info.versions.''.all_versions.Where({ $_.version -eq $this.CurrentState.Version }, 'First')
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
      $Object4 = (Invoke-WebRequest -Uri 'https://www.synology.com/api/releaseNote/findChangeLog?identify=SynologyDriveClient&lang=zh-cn').Content | ConvertFrom-Json -AsHashtable

      $ReleaseNotesCNObject = $Object4.info.versions.''.all_versions.Where({ $_.version -eq $this.CurrentState.Version }, 'First')
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
