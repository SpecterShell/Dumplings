$Object1 = Invoke-WebRequest -Uri 'https://www.cryptotech.com.pl/pomoc-techniczna/oprogramowanie/' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//div[contains(@class, "entry-content")]/div/section[contains(@class, "vc_section")]/div[contains(@class, "vc_row ") and contains(.//h2, "CryptoCard Suite Graphite (32bit MSI)")]')
$VersionX86 = [regex]::Match($Object2.InnerText, 'wersja (\d+(?:\.\d+)+)').Groups[1].Value
$Object3 = $Object1.SelectSingleNode('//div[contains(@class, "entry-content")]/div/section[contains(@class, "vc_section")]/div[contains(@class, "vc_row ") and contains(.//h2, "CryptoCard Suite Graphite (64bit MSI)")]')
$VersionX64 = [regex]::Match($Object3.InnerText, 'wersja (\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://www.cryptotech.com.pl/?wpdmdl=$($Object2.SelectSingleNode('.//a[contains(@class, "wpdm-download-link")]').Attributes['data-package'].Value)"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://www.cryptotech.com.pl/?wpdmdl=$($Object3.SelectSingleNode('.//a[contains(@class, "wpdm-download-link")]').Attributes['data-package'].Value)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::Parse(
        [regex]::Match($Object3.InnerText, '(\d{1,2}\W+\w+\W+20\d{2})').Groups[1].Value,
        (Get-Culture -Name 'pl-PL')
      ).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
