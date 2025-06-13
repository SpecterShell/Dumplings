$Object1 = Invoke-RestMethod -Uri 'https://www.snapgene.com/latestRelease.php?appName=SnapGene&os=windows&architecture=x86_64'

# Version
$this.CurrentState.Version = $Object1.Release.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Release.File.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.snapgene.com/updates' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@class='updates-page-template__list-item-title' and contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::div[@class="updates-page-template__list-item-date"]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::div[@class="updates-page-template__list-item-description"]') | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = Join-Uri 'https://www.snapgene.com/updates' $ReleaseNotesTitleNode.SelectSingleNode('.//a').Attributes['href'].Value
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
