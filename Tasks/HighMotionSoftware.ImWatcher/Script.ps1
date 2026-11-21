$Object1 = Invoke-WebRequest -Uri 'https://www.highmotionsoftware.com/upd/imwatcher/version' | Read-ResponseContent

# Version
$this.CurrentState.Version = $Object1.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.highmotionsoftware.com/download/imwatcher/file/imwatcher-setup.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.highmotionsoftware.com/download-center/imwatcher' | ConvertFrom-Html

      if ($Object2.SelectSingleNode('//strong[text()="Version:"]/following-sibling::text()').InnerText.Trim() -eq $this.CurrentState.RealVersion) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object2.SelectSingleNode('//strong[text()="Date:"]/following-sibling::text()').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
      }

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//p[contains(./b/text(), 'ImWatcher v$($this.CurrentState.RealVersion)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not ($Node.Name -eq 'p' -and $Node.InnerText.Contains('ImWatcher v')); $Node = $Node.NextSibling) { $Node }
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
