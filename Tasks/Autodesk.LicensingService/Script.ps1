$Object1 = Invoke-WebRequest -Uri 'https://www.autodesk.com/support/technical/article/caas/tsarticles/ts/f5IhBc15i0kOwzBb8lcEN.html'
$Object2 = $Object1.Content | Get-EmbeddedJson -StartsFrom 'window.__PRELOADED_STATE__ = ' | ConvertFrom-Json
$Object3 = $Object2.caasData.response | Get-EmbeddedLinks

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object3.Where({ try { $_.href.EndsWith('.zip') -and $_.href -match 'win' -and $_.href -match 'Installer' } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object4 = Invoke-WebRequest -Uri 'https://www.autodesk.com/support/technical/article/caas/tsarticles/ts/6jWlafu6rb46GKeh4N2ssk.html'
      $Object5 = $Object4.Content | Get-EmbeddedJson -StartsFrom 'window.__PRELOADED_STATE__ = ' | ConvertFrom-Json
      $Object6 = $Object5.caasData.response | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object6.SelectSingleNode("//p[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'hr'; $Node = $Node.NextSibling) { $Node }
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
