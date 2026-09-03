# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerX86Url = $Global:DumplingsStorage.SonicWallApps.Where({ $_ -match '/ConnectTunnel_x86-[^/]+\.exe$' }, 'First')[0]
}
$VersionX86 = [regex]::Matches($InstallerX86Url, '(\d+(?:\.\d+)+)')[-1].Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerX64Url = $Global:DumplingsStorage.SonicWallApps.Where({ $_ -match '/ConnectTunnel_x64-[^/]+\.exe$' }, 'First')[0]
}
$VersionX64 = [regex]::Matches($InstallerX64Url, '(\d+(?:\.\d+)+)')[-1].Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $InstallerARM64Url = $Global:DumplingsStorage.SonicWallApps.Where({ $_ -match '/ConnectTunnel_arm64-[^/]+\.exe$' }, 'First')[0]
}
$VersionARM64 = [regex]::Matches($InstallerARM64Url, '(\d+(?:\.\d+)+)')[-1].Groups[1].Value

if (@(@($VersionX86, $VersionX64, $VersionARM64) | Sort-Object -Unique).Count -ne 1) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}, arm64: ${VersionARM64}", 'Error')
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
