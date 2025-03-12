$Object1 = Invoke-RestMethod -Uri 'https://www.facebook.com/messenger/desktop/zeratul/update.xml?target=zeratul&platform=win'

# Version
$this.CurrentState.Version = $Object1.enclosure.shortVersionString

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.messenger.com/messenger/desktop/downloadV2/?platform=win'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.description | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = ($InstallerFile | Read-ProductVersionFromExe).Split('.')[0..2] -join '.'

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
    $this.Submit()
  }
}
