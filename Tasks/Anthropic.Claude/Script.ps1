# Installer
$this.CurrentState.Installer += $InstallerX64EXE = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = curl -fsSA $DumplingsInternetExplorerUserAgent -w '%{redirect_url}' 'https://claude.ai/api/desktop/win32/x64/exe/latest/redirect' | Select-Object -Last 1
}
$VersionX64EXE = [regex]::Match($InstallerX64EXE.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerArm64EXE = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = curl -fsSA $DumplingsInternetExplorerUserAgent -w '%{redirect_url}' 'https://claude.ai/api/desktop/win32/arm64/exe/latest/redirect' | Select-Object -Last 1
}
$VersionArm64EXE = [regex]::Match($InstallerArm64EXE.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerX64MSIX = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msix'
  InstallerUrl  = curl -fsSA $DumplingsInternetExplorerUserAgent -w '%{redirect_url}' 'https://claude.ai/api/desktop/win32/x64/msix/latest/redirect' | Select-Object -Last 1
}
$VersionX64MSIX = [regex]::Match($InstallerX64MSIX.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerArm64MSIX = [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'msix'
  InstallerUrl  = curl -fsSA $DumplingsInternetExplorerUserAgent -w '%{redirect_url}' 'https://claude.ai/api/desktop/win32/arm64/msix/latest/redirect' | Select-Object -Last 1
}
$VersionArm64MSIX = [regex]::Match($InstallerArm64MSIX.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

if (@(@($VersionX64EXE, $VersionArm64EXE, $VersionX64MSIX, $VersionArm64MSIX) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: x64 EXE: $VersionX64EXE, arm64 EXE: $VersionArm64EXE, x64 MSIX: $VersionX64MSIX, arm64 MSIX: $VersionArm64MSIX", 'Error')
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
