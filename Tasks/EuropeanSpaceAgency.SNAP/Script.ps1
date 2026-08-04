$Object1 = Invoke-WebRequest -Uri 'https://step.esa.int/downloads/VERSION.txt'

# Version
$this.CurrentState.Version = $Object1.Content.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.esa.int/step/snap/$($this.CurrentState.Version.Split('.')[0..1] -join '.')/installers/esa-snap_all_windows-$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri "https://step.esa.int/main/wp-content/releasenotes/SNAP/SNAP_$($this.CurrentState.Version).html" | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h1[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2 | Get-TextContent | Format-Text
        }
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
