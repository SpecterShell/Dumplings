$Object1 = Invoke-RestMethod -Uri 'https://www.revouninstaller.com/update.xml'

# Version
$this.CurrentState.Version = $Object1.UNINSTALLER.INFO.VERSION

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = "https://revouninstaller.b-cdn.net/ruf$($this.CurrentState.RealVersion.Replace('.', ''))/revosetup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.revouninstaller.com/version-history/' | ConvertFrom-Html
      $ReleaseNotesObject = $Object2.SelectSingleNode("//article[@class='version' and contains(./h4, '$($this.CurrentState.RealVersion)')]")
      if ($ReleaseNotesObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesObject.SelectSingleNode('.//time').Attributes['datetime'].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject.SelectNodes('.//ul[@class="dlist"]') | Get-TextContent | Format-Text
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
