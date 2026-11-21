$Object1 = Invoke-WebRequest -Uri 'https://www.certags.com/label-printers/complypro-downloads/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href -match 'ComplyPro' } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'V(\d+(?:[\._]\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
      $Installer['NestedInstallerFiles'] = @([ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.Name -eq 'Setup.msi' }, 'First')[0].FullName.Replace('/', '\') })
      $ZipFile.Dispose()
      $InstallerFileExtracted = New-TempFolder
      7z.exe x -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $Installer.NestedInstallerFiles[0].RelativeFilePath | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted $Installer.NestedInstallerFiles[0].RelativeFilePath
      # RealVersion
      $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    }

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
