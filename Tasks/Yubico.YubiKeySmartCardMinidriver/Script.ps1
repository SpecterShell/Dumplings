$Object1 = Invoke-WebRequest -Uri 'https://www.yubico.com/support/download/smart-card-drivers-tools/'

# Installer
$Link = $Object1.Links.Where({ try { $_.href.Contains('Minidriver') -and $_.href.EndsWith('.msi') -and $_.href.Contains('x86') } catch {} }, 'First')
$VersionX86 = [regex]::Match($Link.outerHTML, '(\d+(?:\.\d+)+)').Groups[1].Value
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://downloads.yubico.com/support/YubiKey-Minidriver-${VersionX86}-x86.msi"
}

$Link = $Object1.Links.Where({ try { $_.href.Contains('Minidriver') -and $_.href.EndsWith('.msi') -and $_.href.Contains('x64') } catch {} }, 'First')
$VersionX64 = [regex]::Match($Link.outerHTML, '(\d+(?:\.\d+)+)').Groups[1].Value
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://downloads.yubico.com/support/YubiKey-Minidriver-${VersionX64}-x64.msi"
}

$Link = $Object1.Links.Where({ try { $_.href.Contains('Minidriver') -and $_.href.EndsWith('.msi') -and $_.href.Contains('arm64') } catch {} }, 'First')
$VersionARM64 = [regex]::Match($Link.outerHTML, '(\d+(?:\.\d+)+)').Groups[1].Value
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://downloads.yubico.com/support/YubiKey-Minidriver-${VersionARM64}-arm64.msi"
}

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
