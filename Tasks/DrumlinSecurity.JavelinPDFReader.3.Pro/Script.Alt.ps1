$Object1 = Invoke-RestMethod -Uri 'https://www.drumlinsecurity.co.uk/Service.asmx' -Method Post -Body @'
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <GetLatestVersion xmlns="http://drumlinsecurity.co.uk/">
      <sAppID>JW3P</sAppID>
    </GetLatestVersion>
  </soap:Body>
</soap:Envelope>
'@ -ContentType 'text/xml; charset=utf-8'
$Object2 = $Object1.Envelope.Body.GetLatestVersionResponse.GetLatestVersionResult.diffgram.FullVersionDS.FullVersion

# Version
$this.CurrentState.Version = "$($Object2.Major).$($Object2.Minor).$($Object2.Revision).$($Object2.Extra)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://www.drumlinsecurity.com/kits/windows/javelin$($this.CurrentState.Version)prosetup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.drumlinsecurity.com/releasenotes.php' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//h4[contains(text(), 'Javelin') and contains(text(), 'Pro') and contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}[a-zA-Z]+\W+20\d{2})').Groups[1].Value,
          [string[]]@(
            "MMMM d'st' yyyy",
            "MMMM d'nd' yyyy",
            "MMMM d'rd' yyyy",
            "MMMM d'th' yyyy"
          ),
          (Get-Culture -Name 'en-US'),
          [System.Globalization.DateTimeStyles]::None
        ).ToString('yyyy-MM-dd')

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h4'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
