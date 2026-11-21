$Prefix = 'https://www.terminalworks.com/remote-desktop-printing/downloads'
$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match($Object1.SelectSingleNode('//h4[contains(@class, "tsd-h4") and contains(., "TSPrint Client")]/span[contains(@class, "tsd-v")]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = Join-Uri $Prefix $Object1.SelectSingleNode('//input[@name="tsd-win" and @value="exe"]').Attributes['data-url'].Value
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = Join-Uri $Prefix $Object1.SelectSingleNode('//input[@name="tsd-win" and @value="msi"]').Attributes['data-url'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesTitleNode = $Object1.SelectSingleNode("//h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::span[1]')
        if ($ReleaseTimeNode -and $ReleaseTimeNode.InnerText -match '(\d{1,2}/\d{1,2}/20\d{2})') {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Matches[1], 'MM/dd/yyyy', $null).ToString('yyyy-MM-dd')

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
            Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
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
