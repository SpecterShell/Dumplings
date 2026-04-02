$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://www.centbrowser.com/' | Join-String -Separator "`n" | Get-EmbeddedLinks

# Installer
$InstallerUrl = $Object1.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl -replace '_x64'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://www.centbrowser.com/history.html' | Join-String -Separator "`n" | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//html/body/div[2]/div/div[contains(./p/text()[1], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesNode.SelectSingleNode('./p/i').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./span') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.centbrowser.cn/history.html' | ConvertFrom-Html

      $ReleaseNotesCNNode = $Object3.SelectSingleNode("//html/body/div[2]/div/div[contains(./p/text()[1], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesCNNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [regex]::Match(
          $ReleaseNotesCNNode.SelectSingleNode('./p/i').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNode.SelectSingleNode('./span') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
