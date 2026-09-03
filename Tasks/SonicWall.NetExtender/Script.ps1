# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = $InstallerX86MSIUrl = $Global:DumplingsStorage.SonicWallApps.Where({ $_ -match '/NetExtender-x86-[^/]+\.msi$' }, 'First')[0]
}
$VersionX86MSI = [regex]::Match($InstallerX86MSIUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $InstallerX64MSIUrl = $Global:DumplingsStorage.SonicWallApps.Where({ $_ -match '/NetExtender-x64-[^/]+\.msi$' }, 'First')[0]
}
$VersionX64MSI = [regex]::Match($InstallerX64MSIUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'wix'
  InstallerUrl  = $InstallerARM64MSIUrl = $Global:DumplingsStorage.SonicWallApps.Where({ $_ -match '/NetExtender-arm64-[^/]+\.msi$' }, 'First')[0]
}
$VersionARM64MSI = [regex]::Match($InstallerARM64MSIUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'nullsoft'
  InstallerUrl  = $InstallerX86EXEUrl = $Global:DumplingsStorage.SonicWallApps.Where({ $_ -match '/NXSetupU-x86-[^/]+\.exe$' }, 'First')[0]
}
$VersionX86EXE = [regex]::Match($InstallerX86EXEUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $InstallerX64EXEUrl = $Global:DumplingsStorage.SonicWallApps.Where({ $_ -match '/NXSetupU-x64-[^/]+\.exe$' }, 'First')[0]
}
$VersionX64EXE = [regex]::Match($InstallerX64EXEUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $InstallerARM64EXEUrl = $Global:DumplingsStorage.SonicWallApps.Where({ $_ -match '/NXSetupU-arm64-[^/]+\.exe$' }, 'First')[0]
}
$VersionARM64EXE = [regex]::Match($InstallerARM64EXEUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

if (@(@($VersionX86MSI, $VersionX64MSI, $VersionARM64MSI, $VersionX86EXE, $VersionX64EXE, $VersionARM64EXE) | Sort-Object -Unique).Count -ne 1) {
  $this.Log("Inconsistent versions: x86 MSI: ${VersionX86MSI}, x64 MSI: ${VersionX64MSI}, arm64 MSI: ${VersionARM64MSI}, x86 EXE: ${VersionX86EXE}, x64 EXE: ${VersionX64EXE}, arm64 EXE: ${VersionARM64EXE}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64MSI

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
