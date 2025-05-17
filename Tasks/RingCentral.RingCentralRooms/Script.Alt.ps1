$Object1 = Invoke-RestMethod -Uri 'https://rooms.ringcentral.com/rooms/Windows/Config/windows_rooms_config.json'

# Version
$this.CurrentState.Version = $Object1.room_version.host_version

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://rooms.ringcentral.com/rooms/Windows/download/RingCentralRooms.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://support.ringcentral.com/release-notes/ringex/video/rooms.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//b[contains(text(), '$($this.CurrentState.RealVersion)')]//ancestor::div[contains(@class, 'custom-text ')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.InnerText.Contains('VERSION'); $Node = $Node.NextSibling) {
          if (-not $Node.InnerText.Contains('Release date')) {
            $Node
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
