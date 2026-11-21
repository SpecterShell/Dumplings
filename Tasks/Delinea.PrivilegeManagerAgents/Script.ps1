$Object1 = $Global:DumplingsStorage.DelineaDownloadPage.SelectSingleNode('//tr[contains(./td[2], "Bundled Privilege Manager Agent")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object1.SelectSingleNode('./td[1]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('./td[2]//a').Attributes['href'].Value
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
