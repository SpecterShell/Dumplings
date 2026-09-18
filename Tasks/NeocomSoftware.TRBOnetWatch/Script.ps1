$InstallerUrl = $Global:DumplingsStorage.NeocomSoftwareDownloadPage.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('TRBOnet.Watch') } catch {} }, 'First')[0].href

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType       = 'zip'
  NestedInstallerType = 'exe'
  InstallerUrl        = $InstallerUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
    $this.CurrentState.Installer[0]['NestedInstallerFiles'] = @([ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.Name.EndsWith('.exe') }, 'First')[0].FullName.Replace('/', '\') })
    $ZipFile.Dispose()
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath
    try {
      # RealVersion
      $this.CurrentState.RealVersion = (Get-AdvancedInstallerMsiInfo -Path $InstallerFile2 -Name 'msi.x64.msi').DisplayVersion
    } finally {
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
