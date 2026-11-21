$Object1 = Invoke-WebRequest -Uri 'https://viva.systems/download/?wpdmdl=8052' -Method Head -ConnectionTimeoutSeconds 90
$Filename = [regex]::Match($Object1.Headers.'Content-Disposition', 'filename="?([^";]+)"?').Groups[1].Value

# Version
$this.CurrentState.Version = [regex]::Match($Filename, '(\d+(?:\.\d+)+)').Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'msi'
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "$($Filename | Split-Path -LeafBase)\$($Filename | Split-Path -LeafBase).msi" })
  InstallerUrl         = 'https://viva.systems/download/?wpdmdl=8052'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe x -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

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
