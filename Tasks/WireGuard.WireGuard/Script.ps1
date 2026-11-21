$Prefix = 'https://download.wireguard.com/windows-client/'
$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.sig"

# Installer
$VersionMatches = [regex]::Match($Object1, '(wireguard-x86-(\d+(?:\.\d+)+)\.msi)')
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri $Prefix $VersionMatches.Groups[1].Value
}
$VersionX86 = $VersionMatches.Groups[2].Value

$VersionMatches = [regex]::Match($Object1, '(wireguard-amd64-(\d+(?:\.\d+)+)\.msi)')
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $VersionMatches.Groups[1].Value
}
$VersionX64 = $VersionMatches.Groups[2].Value

$VersionMatches = [regex]::Match($Object1, '(wireguard-arm64-(\d+(?:\.\d+)+)\.msi)')
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri $Prefix $VersionMatches.Groups[1].Value
}
$VersionARM64 = $VersionMatches.Groups[2].Value

if (@(@($VersionX86, $VersionX64, $VersionARM64) | Sort-Object -Unique).Count -gt 1) {
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
