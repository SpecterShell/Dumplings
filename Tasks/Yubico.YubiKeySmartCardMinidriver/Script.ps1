$Object1 = Invoke-WebRequest -Uri 'https://www.yubico.com/support/download/smart-card-drivers-tools/'

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.Links.Where({ try { $_.href.Contains('Minidriver') -and $_.href.EndsWith('.msi') -and $_.href.Contains('x86') } catch {} }, 'First')[0].href
}
$VersionX86 = [regex]::Match($InstallerX86.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Links.Where({ try { $_.href.Contains('Minidriver') -and $_.href.EndsWith('.msi') -and $_.href.Contains('x64') } catch {} }, 'First')[0].href
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
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
