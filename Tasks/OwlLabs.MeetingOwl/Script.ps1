# EXE
$this.CurrentState.Installer += $InstallerEXE = [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = 'https://dashboard.barn.owllabs.com/products/DESKTOPAPP/download/latest/exe'
}
$VersionEXE = [regex]::Match((Get-RedirectedUrl1st -Uri $InstallerEXE.InstallerUrl), '(\d+(?:\.\d+)+\(\d+\))').Groups[1].Value

# MSIX
$this.CurrentState.Installer += $InstallerMSIX = [ordered]@{
  InstallerType       = 'zip'
  NestedInstallerType = 'msix'
  InstallerUrl        = 'https://dashboard.barn.owllabs.com/products/DESKTOPAPP/download/latest/msix'
}
$VersionMatches = [regex]::Match((Get-RedirectedUrl1st -Uri $InstallerMSIX.InstallerUrl), '((\d+(?:\.\d+)+)\((\d+)\))')
$VersionMSIX = $VersionMatches.Groups[1].Value

if ($VersionEXE -ne $VersionMSIX) {
  $this.Log("Inconsistent versions: EXE: ${VersionEXE}, MSI: ${VersionMSIX}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionMatches.Groups[2..3].Value -join '.'

# AppsAndFeaturesEntries
$InstallerEXE['AppsAndFeaturesEntries'] = @(
  [ordered]@{
    DisplayName    = 'Meeting Owl Uninstaller'
    Publisher      = 'Owl Labs, Inc.'
    DisplayVersion = $VersionEXE
  }
)

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
