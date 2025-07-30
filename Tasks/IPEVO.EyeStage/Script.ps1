$Object1 = Invoke-WebRequest -Uri 'https://us.ipevo.com/pages/eyestage-download' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode("//text()[.='Windows 10/11 64bit']/following::a[contains(., 'Download')]").Attributes['href'].Value | ConvertTo-HtmlDecodedText
}

# Version
$this.CurrentState.Version = [regex]::Match((Get-RedirectedUrl -Uri $this.CurrentState.Installer[0].InstallerUrl), '(\d+(?:\.\d+)+)').Groups[1].Value

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
