$Object1 = $Global:DumplingsStorage.KIRDownloadPage.SelectSingleNode('//div[@class="drivers__text" and contains(., "Szafir wersja MSI") and contains(., "Windows") and contains(., "32-bit")]')
$VersionX86Matches = [regex]::Match($Object1.InnerText, '(\d+(?:\.\d+)+)\.?\s*build (\d+)')
$VersionX86 = "$($VersionX86Matches.Groups[1].Value).$($VersionX86Matches.Groups[2].Value)"

$Object2 = $Global:DumplingsStorage.KIRDownloadPage.SelectSingleNode('//div[@class="drivers__text" and contains(., "Szafir wersja MSI") and contains(., "Windows") and contains(., "64-bit")]')
$VersionX64Matches = [regex]::Match($Object2.InnerText, '(\d+(?:\.\d+)+)\.?\s*build (\d+)')
$VersionX64 = "$($VersionX64Matches.Groups[1].Value).$($VersionX64Matches.Groups[2].Value)"

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.SelectSingleNode('./following-sibling::a[contains(@class, "drivers__link")]').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.SelectSingleNode('./following-sibling::a[contains(@class, "drivers__link")]').Attributes['href'].Value
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
