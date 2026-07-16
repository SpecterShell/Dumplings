$Object1 = Invoke-WebRequest -Uri 'https://www.avid.com/products/avid-link' | ConvertFrom-Html
$Object2 = [Newtonsoft.Json.Linq.JObject]::Parse($Object1.SelectSingleNode('//script[@id="__NEXT_DATA__"]').InnerHtml).SelectTokens('$..[?(@.text && @.text =~ /Download for Windows/)]').Where({ $true }, 'First')[0].ToString() | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.url | ConvertTo-UnescapedUri
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = New-TempFolder
      7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'AvidLinkSetup.exe' | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'AvidLinkSetup.exe'
      $InstallerInfo = Get-InstallShieldMsiInfo -Path $InstallerFile2 -Name 'Avid Link.msi'
      # RealVersion
      $this.CurrentState.RealVersion = $InstallerInfo.ProductVersion
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
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
