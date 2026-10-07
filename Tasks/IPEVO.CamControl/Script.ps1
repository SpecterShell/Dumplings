$Object1 = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://us.ipevo.com/pages/camcontrol-download'
  Read-PlaywrightPageContent -Page $Page
} | ConvertFrom-Html

$InstallerUrl = $Object1.SelectSingleNode("//text()[.='Windows 10 (19041) and above']/following::a[contains(., 'Download')]").Attributes['href'].Value | ConvertTo-HtmlDecodedText
$RedirectedInstallerUrl = Get-RedirectedUrl -Uri $InstallerUrl

# Version
$this.CurrentState.Version = [regex]::Match($RedirectedInstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = $RedirectedInstallerUrl | Split-Path -LeafBase
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
