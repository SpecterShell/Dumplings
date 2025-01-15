$Object1 = $Global:DumplingsStorage.JetBrainsApps.YTD.release

# Version
$this.CurrentState.Version = "$($Object1.version).$($Object1.build)".Substring(2)

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $Object1.downloads.zip.link
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "youtrack-$($Object1.version).$($Object1.build)\bin\youtrack.bat"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.date | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.notesLink
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
