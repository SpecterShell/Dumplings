$Object1 = Invoke-RestMethod -Uri 'https://updates.bbconsult.co.uk/Updates.asmx' -Method Post -Headers @{
  SOAPAction = 'http://tempuri.org/GetProductBuilds'
} -Body @'
<?xml version="1.0"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <SOAP-ENV:Body>
    <GetProductBuilds xmlns="http://tempuri.org/">
      <productName>FBX</productName>
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

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://fbx.gg/change-history/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@data-widget_type='button.default' and contains(., 'V$($this.CurrentState.Version.Split('.')[0..1] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::div[@data-widget_type="heading.default"]')
        if ($ReleaseTimeNode) {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
            [regex]::Match(
              $ReleaseTimeNode.InnerText,
              '(\d{1,2}(?:st|nd|rd|th)\W+[a-zA-Z]+\W+20\d{2})'
            ).Groups[1].Value,
            [string[]]@(
              "d'st' MMMM yyyy"
              "d'nd' MMMM yyyy"
              "d'rd' MMMM yyyy"
              "d'th' MMMM yyyy"
            ),
            (Get-Culture -Name 'en-US'),
            [System.Globalization.DateTimeStyles]::None
          ).ToString('yyyy-MM-dd')

          $ReleaseNotesNodes = for ($Node = $ReleaseTimeNode.NextSibling; $Node -and -not ($Node.Attributes.Contains('data-widget_type') -and $Node.Attributes['data-widget_type'].Value -eq 'divider.default'); $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not ($Node.Attributes.Contains('data-widget_type') -and $Node.Attributes['data-widget_type'].Value -eq 'divider.default'); $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
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
