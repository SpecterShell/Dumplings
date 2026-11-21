$Object1 = Invoke-RestMethod -Uri 'https://dl.anyware.hp.com/ztqM7i47Dt06ETYM/pcoip-client/raw/names/pcoip-client-info/versions/exe/pcoip-client-exe-info.json'

# Version
$this.CurrentState.Version = $Object1[0].currentVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://dl.anyware.hp.com/DeAdBCiUYInHcSTy/pcoip-client/raw/names/pcoip-client-exe/versions/$($this.CurrentState.Version)/pcoip-client_$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
