$Object1 = $Global:DumplingsStorage.SeewoApps['SeewoInput']

# Version
$this.CurrentState.Version = [regex]::Match($Object1.softInfos.Where({ $_.useSystem -eq 1 }, 'First')[0].softVersion, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.softInfos.Where({ $_.useSystem -eq 1 }, 'First')[0].downloadUrl
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
