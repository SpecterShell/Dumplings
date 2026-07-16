$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://logtagrecorders.com/updates/logtagsw.ver' | Join-String -Separator "`n" | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.Analyzer_3.Version
$VersionParts = $this.CurrentState.Version.Split('.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Analyzer_3.FileLnk_URL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    $InstallerInfo = Get-AdvancedInstallerMsiInfo -Path $InstallerFile
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerInfo.ProductVersion

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://logtagrecorders.com/logtag-analyzer-3-release-notes/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//p[contains(./strong, '$($VersionParts[0..1] -join '.') RELEASE $($VersionParts[2])')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.SelectSingleNode('.//strong'); $Node = $Node.NextSibling) { $Node }
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
