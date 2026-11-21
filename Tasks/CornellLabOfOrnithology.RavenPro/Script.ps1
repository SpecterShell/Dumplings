$Object1 = Invoke-WebRequest -Uri 'https://www.ravensoundsoftware.com/raven-pro-downloads/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = $Object1.Links.Where({ try { $_.href.Contains('.exe') -and $_.href -match 'RavenPro' -and $_.href -match 'windows' -and $_.href -match 'installer' } catch {} }, 'First')[0].href.Trim()
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
