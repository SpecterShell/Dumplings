# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri 'https://www.xmind.app/xmind/downloads/' (Get-RedirectedUrl -Uri 'https://xmind.app/zen/download/win64/' | Split-Path -Leaf)
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri 'https://www.xmind.app/xmind/downloads/' (Get-RedirectedUrl -Uri 'https://xmind.app/zen/download/win_arm64/' | Split-Path -Leaf)
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object1 = Invoke-WebRequest -Uri 'https://xmind.app/desktop/release-notes/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object1.SelectSingleNode("//div[@class='version-block' and contains(./h3/text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesTitleNode.SelectSingleNode('./h5').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./h5/following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://xmind.cn/desktop/release-notes/' | ConvertFrom-Html

      $ReleaseNotesCNTitleNode = $Object2.SelectSingleNode("//div[@class='version-block' and contains(./h3/text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesCNTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= $ReleaseNotesCNTitleNode.SelectSingleNode('./h5').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNTitleNode.SelectNodes('./h5/following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
