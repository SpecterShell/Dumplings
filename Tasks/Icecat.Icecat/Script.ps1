$Object1 = Invoke-WebRequest -Uri 'https://icecatbrowser.org/all_downloads.html'

$InstallerX64Url = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('win64') -and -not $_.href.Contains('aarch64') } catch {} }, 'First')[0].href
$VersionX64 = [regex]::Match($InstallerX64Url, '(\d+(?:\.\d+)+)').Groups[1].Value

$InstallerArm64Url = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('aarch64') } catch {} }, 'First')[0].href
$VersionArm64 = [regex]::Match($InstallerArm64Url, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionX64 -ne $VersionArm64) {
  $this.Log("x64 version: ${VersionX64}")
  $this.Log("ARM64 version: ${VersionArm64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerX64Url
  ProductCode  = "IceCat $($this.CurrentState.Version) (x64 en-US)"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $InstallerArm64Url
  ProductCode  = "IceCat $($this.CurrentState.Version) (AArch64 en-US)"
}

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
