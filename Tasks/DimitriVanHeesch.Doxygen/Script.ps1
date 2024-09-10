$Object1 = Invoke-WebRequest -Uri 'https://www.doxygen.nl/download.html'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('setup') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '-(\d+(\.\d+){2,})[-.]').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.doxygen.nl/manual/changelog.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@class='textblock']/h2[contains(., 'Release $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('following-sibling::*[1]')
        try {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
            [regex]::Match($ReleaseNotesTimeNode.InnerText, '(\d{1,2}-\d{1,2}-\d{4})').Groups[1].Value,
            'dd-MM-yyyy',
            $null
          ).ToString('yyyy-MM-dd')

          # ReleaseNotes (en-US)
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTimeNode.NextSibling; $Node -and $Node.Name -notin @('h1', 'h2'); $Node = $Node.NextSibling) { $Node }
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } catch {
          $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')

          # ReleaseNotes (en-US)
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -notin @('h1', 'h2'); $Node = $Node.NextSibling) { $Node }
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
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
