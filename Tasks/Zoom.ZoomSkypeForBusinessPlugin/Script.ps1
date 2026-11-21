$Object1 = Invoke-RestMethod -Uri 'https://zoom.us/rest/download?os=win'

# Version
$this.CurrentState.Version = $Object1.result.downloadVO.lyncPlugin.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://zoom.us/client/$($this.CurrentState.Version)/$($Object1.result.downloadVO.lyncPlugin.packageName)"
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
