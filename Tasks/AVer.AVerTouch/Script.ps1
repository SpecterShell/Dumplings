$Object1 = Invoke-RestMethod -Uri 'https://download.aver.com/AVerTouchWindows/check4Update/update.cfg' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.OTA.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.OTA.Path | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.OTA.ReleaseDate | Get-Date -Format 'yyyy-MM-dd'
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
