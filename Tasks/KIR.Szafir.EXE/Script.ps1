$Object1 = $Global:DumplingsStorage.KIRDownloadPage.SelectSingleNode('//div[@class="drivers__text" and contains(., "Szafir EXE version") and contains(., "Windows")]')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('./following-sibling::a[contains(@class, "drivers__link")]').Attributes['href'].Value
}
$VersionMatches = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)_b(\d+)')

# Version
$this.CurrentState.Version = "$($VersionMatches.Groups[1].Value).$($VersionMatches.Groups[2].Value)"

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
