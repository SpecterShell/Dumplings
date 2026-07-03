$Object1 = (Invoke-RestMethod -Uri 'https://cdn.console.gotoresolve.com/dtc/update.json').infos.Where({ $_.product -eq 'resolve' }, 'First')[0].updates[-1]

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-RestMethod -Uri 'https://support.logmein.com/api/i/resolve/help/whats-new-in-the-logmein-resolve-desktop-technician-console'
      $Object3 = $Object2.components.Where({ $_.component -eq 'BrowseTree' }, 'First')[0].data.articleBody.content | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
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
