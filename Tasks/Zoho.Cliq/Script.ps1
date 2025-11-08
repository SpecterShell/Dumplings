$Object1 = Invoke-RestMethod -Uri 'https://downloads.zohocdn.com/chat-desktop/artifacts.json'

# Installer
$this.CurrentState.Installer += $InstallerX86EXE = [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'exe'
  InstallerUrl  = $Object1.windows.'32bit'
}
$VersionX86EXE = [regex]::Match($InstallerX86EXE.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerX64EXE = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = $Object1.windows.'64bit'
}
$VersionX64EXE = [regex]::Match($InstallerX64EXE.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerX86MSI = [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = $Object1.win_msi.'32bit'
}
$VersionX86MSI = [regex]::Match($InstallerX86MSI.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerX64MSI = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Object1.win_msi.'64bit'
}
$VersionX64MSI = [regex]::Match($InstallerX64MSI.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

if (@(@($VersionX86EXE, $VersionX64EXE, $VersionX86MSI, $VersionX64MSI) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions detected: x86 EXE: ${VersionX86EXE}, x64 EXE: ${VersionX64EXE}, x86 MSI: ${VersionX86MSI}, x64 MSI: ${VersionX64MSI}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64EXE

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
