$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://support.freedomscientific.com/Downloads/OfflineInstallers/GetInstallers?product=Fusion&version=17&language=mul&releaseType=Offline' | Join-String -Separator "`n" | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1[0].InstallerLocationHTTP
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+){3,})').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $Object2 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://support.freedomscientific.com/Downloads/Fusion/PreviousFeatures?version=2023' | Join-String -Separator "`n" | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h2[contains(text(), '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
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
