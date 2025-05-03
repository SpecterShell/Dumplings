# x86
$Object1 = $Global:DumplingsStorage.DelineaDownloadPage.SelectSingleNode('//tr[contains(./td[2], "Local Security Solution Agent (x86)")]')
$VersionX86 = [regex]::Match($Object1.SelectSingleNode('./td[1]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value
# x64
$Object2 = $Global:DumplingsStorage.DelineaDownloadPage.SelectSingleNode('//tr[contains(./td[2], "Local Security Solution Agent (x64)")]')
$VersionX64 = [regex]::Match($Object2.SelectSingleNode('./td[1]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
# x86
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('./td[2]//a').Attributes['href'].Value
}
# x64
$this.CurrentState.Installer += [ordered]@{
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
