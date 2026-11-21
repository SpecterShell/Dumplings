$Object1 = Invoke-RestMethod -Uri 'https://rdc.adobe.io/adm/actionList?installerName=readerdc_mui_a_install.exe&defaultInstallerName=readerdc_mui&os=windows' -Headers @{ 'X-API-Key' = 'dc-rdc-adm-client' }
$Object2 = $Object1.productList.Where({ $_.title -eq 'Adobe Acrobat Reader' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.downloadUrl
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
