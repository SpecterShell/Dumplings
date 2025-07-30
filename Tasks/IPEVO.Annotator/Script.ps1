$Object1 = Invoke-WebRequest -Uri 'https://us.ipevo.com/pages/annotator-download' | ConvertFrom-Html

$InstallerUrl = $Object1.SelectSingleNode("//text()[.='Windows 7 / 8 / 10 / 11']/following::a[contains(., 'Download')]").Attributes['href'].Value | ConvertTo-HtmlDecodedText

# Version
$this.CurrentState.Version = [regex]::Match((Get-RedirectedUrl -Uri $InstallerUrl), '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "Annotator_v$($this.CurrentState.Version).msi"
    }
  )
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
