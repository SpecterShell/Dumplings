# $Object1 = Invoke-RestMethod -Uri 'https://eu01-api.ivideon.com/public/version/client_windows'

$Object1 = Invoke-WebRequest -Uri 'https://www.ivideon.com/downloads/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href -match 'IvideonClient' } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromNSIS

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
