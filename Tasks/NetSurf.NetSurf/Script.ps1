$Object1 = Invoke-WebRequest -Uri 'https://www.netsurf-browser.org/downloads/windows/' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//p[contains(@class, "downloadfirst")]/a')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.InnerText, 'NetSurf (\d+(?:\.\d+)+) for Windows').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version + '.0'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl           = $Object2.Attributes['href'].Value
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = '"' + $this.CurrentState.RealVersion + '"'
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.InnerText, '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-RestMethod -Uri 'https://download.netsurf-browser.org/netsurf/releases/ChangeLog.txt' | Convert-MarkdownToHtml

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//h2[contains(text(), 'NetSurf $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for the version $($this.CurrentState.Version)", 'Warning')
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
