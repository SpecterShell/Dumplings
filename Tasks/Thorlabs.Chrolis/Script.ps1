$Object1 = $Global:DumplingsStorage.ChrolisApps

# Version
$this.CurrentState.Version = $Object1.ItemID.SoftwarePkg.VersionNumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl = $Object1.ItemID.SoftwarePkg.DownloadLink.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "$($InstallerUrl | Split-Path -LeafBase)\CHROLIS_Installer.exe"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ItemID.SoftwarePkg.ReleaseDate | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = New-TempFolder
      7z.exe x -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath
      # RealVersion
      $this.CurrentState.RealVersion = $InstallerFile2 | Read-FileVersionFromExe
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
