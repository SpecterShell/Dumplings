$Object1 = Invoke-RestMethod -Uri 'https://www.fotosizer.com/VersionInfo.asmx' -Method Post -Headers @{
  SOAPAction = 'http://tempuri.org/IsNewerVersionAvailable'
} -Body @'
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <IsNewerVersionAvailable xmlns="http://tempuri.org/">
      <sInstalledVersion></sInstalledVersion>
    </IsNewerVersionAvailable>
  </soap:Body>
</soap:Envelope>
'@ -ContentType 'text/xml; charset=utf-8'
$Object2 = $Object1.Envelope.Body.IsNewerVersionAvailableResponse.IsNewerVersionAvailableResult | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object2.VersionInfo.NewVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri 'https://downloads.fotosizer.com/' $Object2.VersionInfo.SetupFilename
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.fotosizer.com/Versions' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[contains(./span/text(), 'v$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match(
            $ReleaseNotesTitleNode.InnerText,
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

        # Remove li icon
        $Object2.SelectNodes('//i[contains(@class, "icon-li")]').ForEach({ $_.Remove() })

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'br'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
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
