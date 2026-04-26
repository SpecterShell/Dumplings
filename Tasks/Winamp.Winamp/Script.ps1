$Object1 = (Invoke-RestMethod -Uri 'http://client.winamp.com/update/latest-version.php').Split()

# Version
$this.CurrentState.Version = $Object1[0].Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1[1].Trim() | Split-Uri -LeftPart 'Path'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    # RealVersion
    $this.CurrentState.RealVersion = [regex]::Match(($InstallerFile | Read-ProductVersionFromExe), '\d+(?:\.\d+){2}').Value

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
