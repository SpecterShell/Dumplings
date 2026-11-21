$Object1 = Invoke-WebRequest -Uri 'https://www.editplus.com/download.html' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = $Object1.SelectSingleNode('//*[@id="sub_64"]/a').Attributes['href'].Value
}
$VersionX64 = $InstallerUrlX64 -replace '.+epp(\d)(\d)\d*_0*(\d+).+', '$1.$2.$3.0'

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $InstallerUrlArm64 = $Object1.SelectSingleNode('//*[@id="sub_arm"]/a').Attributes['href'].Value
}
$VersionArm64 = $InstallerUrlArm64 -replace '.+epp(\d)(\d)\d*_0*(\d+).+', '$1.$2.$3.0'

if ($VersionX64 -ne $VersionArm64) {
  $this.Log("x64 version: ${VersionX64}")
  $this.Log("arm64 version: ${VersionArm64}")
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
