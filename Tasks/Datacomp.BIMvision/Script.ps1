$Object1 = Invoke-RestMethod -Uri 'http://store.bimvision.eu/WebService/BIMVision.svc' -Method Post -Headers @{
  SOAPAction = 'http://datacomp.com.pl/IBIMVision/GetVersionInfo'
} -Body @'
<?xml version="1.0"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <SOAP-ENV:Body>
    <GetVersionInfo xmlns="http://datacomp.com.pl">
      <client>
        <Branding xmlns="http://schemas.datacontract.org/2004/07/BIMVisionPluginStore.Web.WebService">BV</Branding>
        <Test xmlns="http://schemas.datacontract.org/2004/07/BIMVisionPluginStore.Web.WebService">false</Test>
      </client>
    </GetVersionInfo>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
'@ -ContentType 'text/xml; charset=utf-8'
$Object2 = $Object1.Envelope.Body.GetVersionInfoResponse.GetVersionInfoResult

# Version
$this.CurrentState.Version = "$($Object2.latest.Major).$($Object2.latest.Minor).$($Object2.latest.Release)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.latest.DownloadLink | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://bimvision.eu/release-notes/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[contains(@class, 'entry-content')]/p[contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(20\d{2}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'p'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
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
