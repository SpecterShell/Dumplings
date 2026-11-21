# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.mineimator.com/dl/mineimator-installer'
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'https://www.mineimatorforums.com/index.php?/forum/19-downloads-and-news/'
      }

      $Object2 = Invoke-RestMethod -Uri 'https://www.mineimatorforums.com/index.php?/forum/19-downloads-and-news.xml/'
      if ($ReleaseNotesUrlObject = $Object2.Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = Join-Uri $ReleaseNotesUrl $ReleaseNotesUrlObject[0].link
        }

        $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

        $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//h2[contains(text(), '$($this.CurrentState.Version)')]")
        if ($ReleaseNotesTitleNode) {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
            [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}[a-zA-Z]+\W+20\d{2})').Groups[1].Value,
            [string[]]@(
              "MMM d'st' yyyy",
              "MMM d'nd' yyyy",
              "MMM d'rd' yyyy",
              "MMM d'th' yyyy"
            ),
            (Get-Culture -Name 'en-US'),
            [System.Globalization.DateTimeStyles]::None
          ).ToString('yyyy-MM-dd')

          # ReleaseNotes (en-US)
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotesUrl (en-US), ReleaseNotes (en-US) and ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
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
