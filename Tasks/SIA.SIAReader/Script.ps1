$Object1 = Invoke-RestMethod -Uri 'https://shop.sia.ch/Secure_Webservice/sr2Stammdaten.svc' -Method Post -Headers @{
  SOAPAction = '"http://tempuri.org/Isr2Stammdaten/GetVersionInfoSecureReader"'
} -Body @'
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>
    <GetVersionInfoSecureReader xmlns="http://tempuri.org/">
      <aOS></aOS>
      <aCurrent_Version></aCurrent_Version>
      <returnMsg />
    </GetVersionInfoSecureReader>
  </s:Body>
</s:Envelope>
'@ -ContentType 'text/xml; charset=utf-8'
$Object2 = $Object1.Envelope.Body.GetVersionInfoSecureReaderResponse.GetVersionInfoSecureReaderResult

# Version
$this.CurrentState.Version = "$($Object2._Version._Major).$($Object2._Version._Minor).$($Object2._Version._Build).$($Object2._Version._Revision)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2._Url
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
