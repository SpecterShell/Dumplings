$Object1 = Invoke-RestMethod -Uri 'https://updatecheck.paessler.com/desk-stable.json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'burn'
  InstallerUrl  = $Object1.windows.'32bit'.base.download
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'burn'
  InstallerUrl  = $Object1.windows.'64bit'.base.download
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = "https://downloads.paessler.com/prtg_desktop/$($this.CurrentState.Version)/32bit/PRTG_Desktop_Full_Installer.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "https://downloads.paessler.com/prtg_desktop/$($this.CurrentState.Version)/64bit/PRTG_Desktop_Full_Installer.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-RestMethod -Uri 'https://updatecheck.paessler.com/desk-notes.json'

      $ReleaseNotesObject = $Object2.releases.Where({ $_.version -eq $this.CurrentState.Version }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesObject[0].date.ToUniversalTime()

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject[0].note | ConvertFrom-Html | Get-TextContent | Format-Text
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
