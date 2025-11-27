$Object1 = $Global:DumplingsStorage.QNAPApps.docRoot.utility.application.Where({ $_.applicationName -eq 'com.qnap.qbackup' }, 'First')[0].platform.Where({ $_.platformName -eq 'Windows' }, 'First')[0].software

# Version
$this.CurrentState.Version = "$($Object1.version).$($Object1.buildNumber)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.downloadURL[0]
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object1.downloadURL[0].Replace('//download.qnap.com/', '//download.qnap.com.cn/')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://www.qnap.com/api/v1/release-notes/utility/NetBak%20Replicator?locale=en').result.notes.Windows.Where({ $_.version -eq $Object1.version }, 'First')

      if ($Object2) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].note | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = (Invoke-RestMethod -Uri 'https://www.qnap.com/api/v1/release-notes/utility/NetBak%20Replicator?locale=zh-cn').result.notes.Windows.Where({ $_.version -eq $Object1.version }, 'First')

      if ($Object3 -and $Object3[0].note -ne $Object2[0].note) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object3[0].note | Format-Text
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
