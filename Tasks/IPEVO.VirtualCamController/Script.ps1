$Object1 = Invoke-WebRequest -Uri 'https://us.ipevo.com/pages/virtualcamcontroller-download' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl = $Object1.SelectSingleNode("//text()[.='Windows 10']/following::a[contains(., 'Download')]").Attributes['href'].Value | ConvertTo-HtmlDecodedText
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = $InstallerUrl | Split-Path -LeafBase
    }
  )
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

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
