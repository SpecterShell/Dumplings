# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl = $Global:DumplingsStorage.HMSDownloadPage.Links.Where({ try { $_.href.Contains('.zip') -and $_.href.Contains('ixxat-cananalyser') } catch {} }, 'First')[0].href | Split-Uri -LeftPart 'Path'
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "$($InstallerUrl | Split-Path -LeafBase).exe"
    }
  )
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:-\d+)+)').Groups[1].Value.Replace('-', '.')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
