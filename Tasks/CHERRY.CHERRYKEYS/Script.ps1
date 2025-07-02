$Object1 = Invoke-WebRequest -Uri 'https://www.cherry.de/en-us/products/software-services/cherry-keys' -Headers @{ 'Accept-Language' = 'en-US' }

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('x86') } catch {} }, 'First')[0].href
}
$VersionX86 = [regex]::Match($InstallerUrlX86, 'x86_(\d+_\d+_\d+)').Groups[1].Value.Replace('_', '.')

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('x64') } catch {} }, 'First')[0].href
}
$VersionX64 = [regex]::Match($InstallerUrlX64, 'x64_(\d+_\d+_\d+)').Groups[1].Value.Replace('_', '.')

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
