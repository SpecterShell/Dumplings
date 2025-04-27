$Prefix = 'https://www.izarc.org/download/'
$Object1 = Invoke-RestMethod -Uri "${Prefix}update.ini" | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.IZArc.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.IZArc.SetupFile
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.izarc.org/news' | ConvertFrom-Html
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[contains(@class, 'sppb-column-addons')]/div[contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.SelectSingleNode('./div[contains(@class, "sppb-addon-divider-wrap")]'); $Node = $Node.NextSibling) { $Node }
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
