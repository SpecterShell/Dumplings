$Object1 = Invoke-RestMethod -Uri 'https://ws.maestro.no/Customers/KaOnline.dll/soap/IMUpdatesInf' -Method Post -Headers @{
  SOAPAction = 'urn:MUpdatesIntf-IMUpdatesInf#GetMUpdates'
} -Body @'
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:MUpdatesIntf-IMUpdatesInf" xmlns:ns1="urn:MUpdatesIntf">
  <soap:Body>
    <urn:GetMUpdates soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
      <ARequest xsi:type="ns1:MUpdatesRequest">
        <Code xsi:type="xsd:string">mas</Code>
        <Year xsi:type="xsd:int">2023</Year>
      </ARequest>
    </urn:GetMUpdates>
  </soap:Body>
</soap:Envelope>
'@ -ContentType 'text/xml; charset=utf-8'

# Version
$this.CurrentState.Version = $Object1.Envelope.Body.GetMUpdatesResponse.return.Versjon.'#text'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Envelope.Body.GetMUpdatesResponse.return.Url.'#text'.Replace('//s3.eu-central-1.amazonaws.com/maestro-mas/', '//maestro-mas.s3.eu-central-1.amazonaws.com/')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.Envelope.Body.GetMUpdatesResponse.return.Dato.'#text' | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
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
