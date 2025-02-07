$Object1 = (Invoke-RestMethod -Uri 'https://www.sweetscape.com/cgibin/010editor_check_news_5k.php').Replace('010EditorNews', 'news') | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.news.newversion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.sweetscape.com/download/010EditorWin32Installer.exe'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.sweetscape.com/download/010EditorWin64Installer.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.sweetscape.com/010editor/release_notes.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@class='contentdiv'][1]/h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          $ReleaseNotesTitleNode.InnerText.Split('-')[-1].Trim(),
          [string[]]@(
            "MMMM d'st', yyyy",
            "MMMM d'nd', yyyy",
            "MMMM d'rd', yyyy",
            "MMMM d'th', yyyy"
          ),
          (Get-Culture -Name 'en-US'),
          [System.Globalization.DateTimeStyles]::None
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'table'; $Node = $Node.NextSibling) { $Node }
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
