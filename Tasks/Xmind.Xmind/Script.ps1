$InstallerX64Url = Join-Uri 'https://www.xmind.app/xmind/downloads/' (Get-RedirectedUrl -Uri 'https://xmind.app/zen/download/win64/' | Split-Path -Leaf)
$VersionX64 = [regex]::Match($InstallerX64Url, '(\d+(?:\.\d+){2,})').Groups[1].Value

$InstallerArm64Url = Join-Uri 'https://www.xmind.app/xmind/downloads/' (Get-RedirectedUrl -Uri 'https://xmind.app/zen/download/win_arm64/' | Split-Path -Leaf)
$VersionArm64 = [regex]::Match($InstallerArm64Url, '(\d+(?:\.\d+){2,})').Groups[1].Value

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerX64Url
}
if ($VersionArm64 -eq $VersionX64) {
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'arm64'
    InstallerUrl = $InstallerArm64Url
  }
} else {
  $this.Log("The version of arm64 installer ($VersionArm64) is different from x64 installer ($VersionX64). Skipped.", 'Warning')
}

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
