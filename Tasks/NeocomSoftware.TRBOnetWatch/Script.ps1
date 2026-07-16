$InstallerUrl = $Global:DumplingsStorage.NeocomSoftwareDownloadPage.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('TRBOnet.Watch') } catch {} }, 'First')[0].href

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType        = 'zip'
  NestedInstallerType  = 'exe'
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "$($InstallerUrl | Split-Path -LeafBase).exe"
    }
  )
  InstallerUrl         = $InstallerUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $NestedInstallerPath = $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath
    $InstallerFileExtracted = Expand-TempArchive -Path $InstallerFile -RelativeFilePath $NestedInstallerPath
    try {
      # RealVersion
      $this.CurrentState.RealVersion = (Get-AdvancedInstallerMsiInfo -Path (Join-Path $InstallerFileExtracted $NestedInstallerPath) -Name 'msi.x64.msi').ProductVersion
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
