$Object1 = Invoke-RestMethod -Uri 'https://www.helpandmanual.com/download/hmsetup.xml'

# Version
$this.CurrentState.Version = $Object1.XML_DIZ_INFO.Program_Info.Program_Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = "https://www.helpandmanual.com/download/help-and-manual-setup-v$($this.CurrentState.Version.Replace('.', '')).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = "https://www.helpandmanual.com/download/help-and-manual-setup-v$($this.CurrentState.Version.Replace('.', '')).msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = Get-Date -Year $Object1.XML_DIZ_INFO.Program_Info.Program_Release_Year `
        -Month $Object1.XML_DIZ_INFO.Program_Info.Program_Release_Month `
        -Day $Object1.XML_DIZ_INFO.Program_Info.Program_Release_Day `
        -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-RestMethod -Uri 'https://www.helpandmanual.com/news/feed/'

      $ReleaseNotesObject = $Object2.Where({ $_.title.Contains("Help+Manual $($this.CurrentState.Version)") }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject[0].encoded.'#cdata-section' | ConvertFrom-Html | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesObject[0].link
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
    if ($this.CurrentState.Version.Split('.')[0] -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
      $this.Log('Major version update. The WinGet package needs to be updated', 'Error')
    } else {
      $this.Submit()
    }
  }
}
