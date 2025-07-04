$Object1 = $Global:DumplingsStorage.QNAPApps.docRoot.utility.application.Where({ $_.applicationName -eq 'com.qnap.qudedupextool' }, 'First')[0].platform.Where({ $_.platformName -eq 'Windows' }, 'First')[0].software

# Version
$this.CurrentState.Version = "$($Object1.version).$($Object1.buildNumber)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.downloadURL[0]
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC

      # ReleaseNotes (en-US)
      # $this.CurrentState.Locale += [ordered]@{
      #   Locale = 'en-US'
      #   Key    = 'ReleaseNotes'
      #   Value  = $Object1.releaseNote.'#cdata-section' | Format-Text
      # }
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
