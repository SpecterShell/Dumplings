$Object1 = Invoke-RestMethod -Uri 'https://updates.bbconsult.co.uk/Updates.asmx' -Method Post -Headers @{
  SOAPAction = 'http://tempuri.org/GetProductBuilds'
} -Body @'
<?xml version="1.0"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <SOAP-ENV:Body>
    <GetProductBuilds xmlns="http://tempuri.org/">
      <productName>FlashBack Pro 5</productName>
      <release>true</release>
      <forceUpdate>false</forceUpdate>
    </GetProductBuilds>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
'@ -ContentType 'text/xml; charset=utf-8'

# Version
$this.CurrentState.Version = $Object1.Envelope.Body.GetProductBuildsResponse.GetProductBuildsResult.LastChild.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Envelope.Body.GetProductBuildsResponse.GetProductBuildsResult.LastChild.Url | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.Envelope.Body.GetProductBuildsResponse.GetProductBuildsResult.LastChild.ReleaseDate | Get-Date
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
