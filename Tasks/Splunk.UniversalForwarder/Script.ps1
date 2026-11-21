$Object1 = Invoke-WebRequest -Uri 'https://www.splunk.com/en_us/download/universal-forwarder.html' | ConvertFrom-Html

# Installer
# $Asset = $Object1.SelectSingleNode('//a[@data-platform="windows" and @data-arch="x86"]')
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x86'
#   InstallerUrl = $Asset.Attributes['data-link'].Value
# }
# $VersionX86 = $Asset.Attributes['data-version'].Value

$Asset = $Object1.SelectSingleNode('//a[@data-platform="windows" and @data-arch="x86_64"]')
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Asset.Attributes['data-link'].Value
}
$VersionX64 = $Asset.Attributes['data-version'].Value

# if ($VersionX86 -ne $VersionX64) {
#   $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Error')
#   return
# }

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
