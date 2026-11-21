$Object1 = Invoke-RestMethod -Uri 'https://dl.eviware.com/version-update/soapui-updates-os.xml'
$Object2 = $Object1.updateDescriptor.entry.Where({ $_.targetMediaFileId -eq '1215' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object2.newVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Object1.updateDescriptor.baseUrl $Object2.fileName
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.soapui.org/downloads/latest-release/release-notes/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//h3[contains(text(), 'SoapUI Open Source $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p[1]')
        if ($ReleaseTimeNode -and (ConvertTo-HtmlDecodedText -Content $ReleaseTimeNode.InnerText) -match '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})') {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'

          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseTimeNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseTime (en-US) for version $($this.CurrentState.Version)", 'Warning')

          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesTitleNode.SelectNodes('./span[1]/following-sibling::node()') | Get-TextContent | Format-Text
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
