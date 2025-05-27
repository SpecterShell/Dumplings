# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.counterpath.com/downloads/Bria6ForWindows.php'
}

# Version
$VersionMatches = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '((\d+(?:\.\d+)+)_\d+)')
$this.CurrentState.Version = $VersionMatches.Groups[1].Value
$ShortVersion = $VersionMatches.Groups[2].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://docs.counterpath.com/docs/DeskUG/clients/ReleaseNotes/current_Desk.htm' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(., '${ShortVersion}')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

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
