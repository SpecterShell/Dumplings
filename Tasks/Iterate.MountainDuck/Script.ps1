$Object1 = Invoke-RestMethod -Uri 'https://version-cdn.mountainduck.io/5/windows/release/changelog.appinstaller'

# Version
$this.CurrentState.Version = $Object1.AppInstaller.MainPackage.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msix'
  InstallerUrl  = $Object1.AppInstaller.MainPackage.Uri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://mountainduck.io/changelog/' | ConvertFrom-Html
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//tr[contains(./td[1], '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./td[1]').InnerText, '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # Add brackets around labels
        $ReleaseNotesTitleNode.SelectNodes('./td[2]//span[contains(@class, "label")]').ForEach({ $_.InnerHtml = "[$($_.InnerText)]" })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./td[2]') | Get-TextContent | Format-Text
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
