$Object1 = Invoke-RestMethod -Uri 'https://e.seewo.com/download/fromSeewoEdu?code=EasiClassPC'

# Version
$this.CurrentState.Version = $Object1.data.softVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
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
