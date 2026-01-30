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
      $Object2 = Invoke-WebRequest -Uri 'https://support.logmein.com/resolve/help/whats-new-in-the-logmein-resolve-desktop-technician-console' | ConvertFrom-Html
      $Object3 = Invoke-RestMethod -Uri "https://support.logmein.com/api2/article/$($Object2.SelectSingleNode('//meta[@name="article-immutable-id"]').Attributes['content'].Value)/en"
      $Object4 = $Object3.contentText | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object4.SelectSingleNode("//h2[contains(text(), '$($this.CurrentState.Version)')]")
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
