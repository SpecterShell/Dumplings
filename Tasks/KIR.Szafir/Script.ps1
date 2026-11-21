$Object1 = $Global:DumplingsStorage.KIRDownloadPage.SelectSingleNode('//div[@class="drivers__text" and contains(., "Szafir wersja MSI") and contains(., "Windows") and contains(., "32-bit")]')
$Object2 = $Global:DumplingsStorage.KIRDownloadPage.SelectSingleNode('//div[@class="drivers__text" and contains(., "Szafir wersja MSI") and contains(., "Windows") and contains(., "64-bit")]')

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('./following-sibling::a[contains(@class, "drivers__link")]').Attributes['href'].Value
}
$VersionX86Matches = [regex]::Match($InstallerX86.InstallerUrl, '(\d+(?:\.\d+)+)_b(\d+)')
$VersionX86 = "$($VersionX86Matches.Groups[1].Value).$($VersionX86Matches.Groups[2].Value)"

$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri $Object2.SelectSingleNode('./following-sibling::a[contains(@class, "drivers__link")]').Attributes['href'].Value
}
$VersionX64Matches = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(?:\.\d+)+)_b(\d+)')
$VersionX64 = "$($VersionX64Matches.Groups[1].Value).$($VersionX64Matches.Groups[2].Value)"

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Error')
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
