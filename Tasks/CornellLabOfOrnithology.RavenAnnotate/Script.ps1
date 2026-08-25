$Object1 = Invoke-RestMethod -Uri 'https://updates.ravensoundsoftware.com/updates/workbench/raven_annotate/win_x64/update.json'

# Version
$this.CurrentState.Version = $Object1.versionId.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = Join-Uri $Object1.downloadLocation $Object1.platformFileList.Where({ $_.platform -eq 'win_x64' }, 'First')[0].filename
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
      $ExtractedPath = New-TempFolder
  
      try {
        7z.exe e -aoa -ba -bd -y '-t#' "-o$ExtractedPath" $InstallerFile '2.msi' | Out-Host
        $MsiPath = Join-Path $ExtractedPath '2.msi'
        $MsiInfo = Get-MsiInstallerInfo -Path $MsiPath
        # RealVersion
        $this.CurrentState.RealVersion = $MsiInfo.DisplayVersion
        # ProductCode
        $Installer.ProductCode = $MsiInfo.ProductCode
        # AppsAndFeaturesEntries
        $Installer.AppsAndFeaturesEntries = @(
          [ordered]@{
            UpgradeCode   = $MsiInfo.UpgradeCode
            InstallerType = $MsiInfo.InstallerType
          }
        )
      } finally {
        Remove-Item -LiteralPath $ExtractedPath -Recurse -Force -ErrorAction SilentlyContinue
      }
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
