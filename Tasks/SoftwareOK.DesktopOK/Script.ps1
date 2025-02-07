$Object1 = Invoke-WebRequest -Uri 'https://www.softwareok.com/?seite=Freeware/DesktopOK/Autoupdate'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'Current version: (\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://www.softwareok.com/Download/DesktopOK_Installer.zip'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://www.softwareok.com/Download/DesktopOK_Installer_x64.zip'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.softwareok.com/?seite=Freeware/DesktopOK/History' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//b[contains(text(), 'New in version $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesTitleNode.InnerText,
          '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.InnerText.Contains('Back to DesktopOK description') -and -not $Node.InnerText.Contains('New in version'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
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
