$Object1 = Invoke-RestMethod -Uri 'https://swupdate.sparklabs.com/appcast/win/release/viscosity/'

# Version
$this.CurrentState.Version = $Object1.update.app.info.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.update.app.info.updateUrl | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.update.app.info.publishedDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri $Object1.update.app.info.releaseNotesLink | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectSingleNode('//div[@class="release-notes-list"]') | Get-TextContent | Format-Text
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
