$Object1 = $Global:DumplingsStorage.PTVDownloads
$Object2 = $Object1.categories.Where({ $_.id -eq 'VISSIM' }, 'First')[0]
$Object3 = $Object2.items.Where({ $_.fileType -eq 'setup' -and $_.isLatest -and $_.edition -eq '64 bit' -and $_.description -eq 'PTV Vissim' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object3.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = "https://cgi.ptvgroup.com/visionSetups/Setups/$($Object3.relPath)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.date

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = "https://cgi.ptvgroup.com/visionSetups/Setups/$($Object2.items.Where({ $_.fileType -eq 'doc' -and $_.isLatest -and $_.description -eq 'Release Notes' -and $_.version -eq $Object3.version }, 'First')[0].relPath)"
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
