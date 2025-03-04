$Object1 = Invoke-RestMethod -Uri "https://static.flicker.cool/flicker/download/stable/$($this.LastState.Contains('Version') ? $this.LastState.Version : '5.4.3')/win32/latest.yml" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://static.flicker.cool/flicker/download/stable/$($this.CurrentState.Version)/win32/$($Object1.files[0].url)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
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
