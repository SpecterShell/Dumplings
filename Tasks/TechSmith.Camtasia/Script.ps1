$Object1 = Invoke-RestMethod -Uri 'https://updater.techsmith.com/TSCUpdate_deploy/Updates.asmx' -Method Post -Body @'
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <CheckForUpdates xmlns="http://localhost/TSCUpdater">
      <product>Camtasia</product>
      <currentVersion>25.0.0</currentVersion>
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
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = $Object1.Envelope.Body.CheckForUpdatesResponse.CheckForUpdatesResult.DownloadLink
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = $Object1.Envelope.Body.CheckForUpdatesResponse.CheckForUpdatesResult.DownloadLink -replace '\.exe$', '.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://support.techsmith.com/hc/en-us/articles/115006443267-Camtasia-Windows-Version-History' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(text(), 'Camtasia 20$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d+\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
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
