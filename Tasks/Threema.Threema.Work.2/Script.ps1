$Object1 = Invoke-RestMethod -Uri 'https://releases.threema.ch/desktop/latest-version-work-windows.json'

# Version
$this.CurrentState.Version = $Object1.latestVersion.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://releases.threema.ch/desktop/$($this.CurrentState.Version)/threema-work-desktop-v$($this.CurrentState.Version)-windows-x64.msix"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMSIX

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://threema.com/en/changelog/desktop-md' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[contains(@id, 'accordion') and contains(@id, 'heading') and contains(., 'Threema Work 2.0 for Desktop') and contains(., 'Beta $([regex]::Match($this.CurrentState.Version, 'beta(\d+)').Groups[1].Value)')]")
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
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::*[contains(@id, "accordion") and contains(@id, "body")]') | Get-TextContent | Format-Text
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
