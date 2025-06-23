$Prefix = 'https://files.wildix.com/integrations/'
$Object1 = Invoke-RestMethod -Uri "${Prefix}applications.json"

# Version
$this.CurrentState.Version = $Object1.applications.collaboration.win.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x64'
  InstallerType          = 'nullsoft'
  InstallerUrl           = Join-Uri $Prefix $Object1.applications.collaboration.win.file
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = $this.CurrentState.Version
    }
  )
}
$this.CurrentState.Installer += $InstallerWiX = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = Join-Uri $Prefix $Object1.applications.collaboration.win.msi
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$InstallerWiX.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerWiX.InstallerUrl
    # AppsAndFeaturesEntries
    $InstallerWiX['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayVersion = $InstallerFile | Read-ProductVersionFromMsi
        UpgradeCode    = $InstallerFile | Read-UpgradeCodeFromMsi
      }
    )

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.wildix.com/new-releases-and-updates/collaboration-native-app-changelog/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//p[contains(./b/text(), 'Version $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{1,2}\.\d{1,2}\.20\d{2})').Groups[1].Value,
          'dd.MM.yyyy',
          $null
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
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
