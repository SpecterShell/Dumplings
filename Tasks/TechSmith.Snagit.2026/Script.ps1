$Object1 = Invoke-RestMethod -Uri 'https://updater.techsmith.com/TSCUpdate_deploy/Updates.asmx' -Method Post -Body @'
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <CheckForUpdates xmlns="http://localhost/TSCUpdater">
      <product>Snagit</product>
      <currentVersion>26.0.0</currentVersion>
      <language>ENU</language>
      <os>10.0.22000.0</os>
      <dotNet>4.8.9037</dotNet>
      <bitness>64</bitness>
    </CheckForUpdates>
  </soap:Body>
</soap:Envelope>
'@ -ContentType 'text/xml; charset=utf-8'

if ($Object1.Envelope.Body.CheckForUpdatesResponse.CheckForUpdatesResult -is [string]) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.Envelope.Body.CheckForUpdatesResponse.CheckForUpdatesResult.NextVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = $Object1.Envelope.Body.CheckForUpdatesResponse.CheckForUpdatesResult.DownloadLink
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = $Object1.Envelope.Body.CheckForUpdatesResponse.CheckForUpdatesResult.DownloadLink -replace '\.exe$', '.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = Get-RedirectedUrl1st -Uri $Object1.Envelope.Body.CheckForUpdatesResponse.CheckForUpdatesResult.InfoLink -Method Get | Split-Uri -LeftPart Path
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(@id, '20$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
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
    $this.Message()
  }
  'New|Updated' {
    if ("20$($this.CurrentState.Version.Split('.')[0])" -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
      $this.Log('Major version update. The WinGet package needs to be updated', 'Error')
    } else {
      $this.Submit()
    }
  }
}
