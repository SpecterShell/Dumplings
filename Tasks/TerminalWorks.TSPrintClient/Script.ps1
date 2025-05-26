$Prefix = 'https://www.terminalworks.com/remote-desktop-printing/downloads'
$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html

# EXE
$Object2 = $Object1.SelectSingleNode('//option[contains(text(), "Windows EXE")]')
$VersionEXE = $Object2.Attributes['version'].Value

# MSI
$Object3 = $Object1.SelectSingleNode('//option[contains(text(), "Windows MSI")]')
$VersionMSI = $Object3.Attributes['version'].Value

if ($VersionEXE -ne $VersionMSI) {
  $this.Log("EXE version: ${VersionEXE}")
  $this.Log("MSI version: ${VersionMSI}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionEXE

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = Join-Uri $Prefix $Object2.Attributes['value'].Value
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = Join-Uri $Prefix $Object3.Attributes['value'].Value
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
