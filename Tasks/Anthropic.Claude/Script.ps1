# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = curl -fsSA $DumplingsInternetExplorerUserAgent -w '%{redirect_url}' 'https://claude.ai/api/desktop/win32/x64/exe/latest/redirect' | Select-Object -Last 1
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerArm64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = curl -fsSA $DumplingsInternetExplorerUserAgent -w '%{redirect_url}' 'https://claude.ai/api/desktop/win32/arm64/exe/latest/redirect' | Select-Object -Last 1
}
$VersionArm64 = [regex]::Match($InstallerArm64.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionX64 -ne $VersionArm64) {
  $this.Log("Inconsistent versions: x64: $VersionX64, arm64: $VersionArm64", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

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
