$Object1 = Invoke-WebRequest -Uri 'https://dupecare.com/' | ConvertFrom-Html

# Version
$ReleaseDetailsTable = $Object1.SelectSingleNode("//table[@id='release-details-info']")
$this.CurrentState.Version = $ReleaseDetailsTable.SelectSingleNode(".//tr[th[contains(normalize-space(), 'Version')]]/td").InnerText.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://dupecare.com/download/dupecare.exe'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = 'https://dupecare.com/download/dupecare-arm64.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $ReleaseDetailsTable.SelectSingleNode('.//time').Attributes['datetime'].Value

      try {
        $Object2 = Invoke-WebRequest -Uri 'https://hhdsoftware.com/dupecare/history' | ConvertFrom-Html

        $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(., '$($this.CurrentState.Version)')]")
        if ($ReleaseNotesTitleNode) {
          $ReleaseNotesItemNode = $ReleaseNotesTitleNode.SelectSingleNode('./ancestor::div[@class="p-vh-item"][1]')
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesItemNode.SelectNodes('.//div[@class="p-vh-item-main-title"]/following-sibling::node()') | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }
      } catch {
        $_ | Out-Host
        $this.Log($_, 'Warning')
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
