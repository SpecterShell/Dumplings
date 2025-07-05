$Object1 = Invoke-WebRequest -Uri 'https://www.scia.net/en/scia-engineer/downloads'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ try { $_.href -match 'release_(\d+(?:\.\d+)+)\.zip$' } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = $Matches[1]

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
