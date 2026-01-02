$Object1 = Invoke-RestMethod -Uri "https://webdownloads2.ts.fujitsu.com/deskupdate_5_1/data/api/v1/update/$($this.Status.Contains('New') ? '5.2.75.0' : $this.LastState.Version)"

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://support.ts.fujitsu.com/Download/StreamFileToBrowser.asp?SoftwareGUID=$($Object1.updateSetupPackage.softwareID.ToUpper())"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.versionDate.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
