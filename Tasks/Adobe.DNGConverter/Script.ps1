# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl1st -Uri 'https://www.adobe.com/go/dng_converter_win' -Method GET
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, 'x64_(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')

$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Get-RedirectedUrl1st -Uri 'https://www.adobe.com/go/dng_converter_winarm' -Method GET
}
$VersionArm64 = [regex]::Match($InstallerARM64.InstallerUrl, 'arm64_(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')

if ($VersionX64 -ne $VersionArm64) {
  $this.Log("Inconsistent versions: x64: ${VersionX64}, arm64: ${VersionArm64}", 'Error')
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
