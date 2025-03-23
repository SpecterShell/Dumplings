$Object1 = Invoke-RestMethod -Uri 'https://applications.it.abb.com/MKDBWCF/ASDAuthService.svc' -Method Post -Headers @{
  SOAPAction = 'MKDBWCF.ASDAuthService/IASDAuthService/ASDGetSoftwareList'
} -Body @'
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>
    <ASDGetSoftwareList xmlns="MKDBWCF.ASDAuthService">
      <email />
      <country
        xmlns:a="http://schemas.datacontract.org/2004/07/MKDBWCF.ExtensibleDataContract"
        xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
        <a:Code>US</a:Code>
        <a:DefaultLanguage i:nil="true" />
        <a:Description i:nil="true" />
      </country>
    </ASDGetSoftwareList>
  </s:Body>
</s:Envelope>
'@ -ContentType 'text/xml; charset=utf-8'
$Object2 = $Object1.Envelope.Body.ASDGetSoftwareListResponse.ASDGetSoftwareListResult.ASDSoftwareEx.Where({ $_.Title -eq 'e-Design' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object2.FullVersion.Release

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.FullVersion.InstallerUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.FullVersion.ReleaseDate | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'e-Design.msi'
      # AppsAndFeaturesEntries + ProductCode
      $Installer.AppsAndFeaturesEntries = @(
        [ordered]@{
          ProductCode   = $Installer.ProductCode = $InstallerFile2 | Read-ProductCodeFromMsi
          UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
          InstallerType = 'msi'
        }
      )
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
