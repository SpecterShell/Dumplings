$Object1 = Invoke-RestMethod -Uri 'https://isl-services.info/miete/VersionService.asmx' -Method Post -Headers @{
  SOAPAction = 'http://tempuri.org/getMainVersion'
} -Body @'
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>
    <getMainVersion xmlns="http://tempuri.org/" xmlns:a="http://schemas.datacontract.org/2004/07/isl_StartBar.ISLService" xmlns:i="http://www.w3.org/2001/XMLSchema-instance" />
  </s:Body>
</s:Envelope>
'@ -ContentType 'text/xml; charset=utf-8'
$Object2 = $Object1.Envelope.Body.getMainVersionResponse.getMainVersionResult

# Version
$this.CurrentState.Version = $Object2.VersionString64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.Path64
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object2.Date64, 'dd.MM.yyyy', $null).ToString('yyyy-MM-dd')
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
