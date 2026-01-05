$Object1 = Invoke-RestMethod -Uri "https://webdownloads2.ts.fujitsu.com/deskupdate_5_1/data/api/v1/update/$($this.Status.Contains('New') ? '5.2.75.0' : $this.LastState.Version)"

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://webdownloads4.ts.fujitsu.com/download/FileDownload/fileDownload.aspx?SoftwareGUID=$($Object1.updateSetupPackage.softwareID.ToUpper())&FileFolder=Downloadfiles&FileTypeExtension=EXE"
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
