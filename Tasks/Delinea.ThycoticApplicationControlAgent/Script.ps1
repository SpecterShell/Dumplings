# x64
$Object1 = $Global:DumplingsStorage.DelineaDownloadPage.SelectSingleNode('//tr[contains(./td[2], "Application Control Agent (x64)")]')
$VersionX64 = [regex]::Match($Object1.SelectSingleNode('./td[1]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value
# arm64
$Object2 = $Global:DumplingsStorage.DelineaDownloadPage.SelectSingleNode('//tr[contains(./td[2], "Application Control Agent (ARM64)")]')
$VersionARM64 = [regex]::Match($Object2.SelectSingleNode('./td[1]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionX64 -ne $VersionARM64) {
  $this.Log("x64 version: ${VersionX64}")
  $this.Log("arm64 version: ${VersionARM64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.SelectSingleNode('./td[2]//a').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object2.SelectSingleNode('./td[2]//a').Attributes['href'].Value
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
