# x64
$Object1 = Invoke-RestMethod -Uri 'https://client-upgrade-a.wbx2.com/client-upgrade/api/v1/webexteamsdesktop/upgrade/@me?channel=gold&model=win-64&partnerOrgId=06441d92-d70e-4d07-9628-f717f39a59a9&r=AC805C72-1377-4FE6-B272-1FB4417B50B7'

# Version
$this.CurrentState.Version = $Object1.manifest.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.manifest.manualInstallPackageLocation
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://cpbx-hilfe.deutschland-lan.de/de/grundlagen/produktneuerungen' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//table/tbody/tr/td[4]/p[contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (de)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'de'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (de) for version $($this.CurrentState.Version)", 'Warning')
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
