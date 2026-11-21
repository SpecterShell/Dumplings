$Object1 = Invoke-RestMethod -Uri 'https://www.wiz.cn/as/blogs/downloads-windows.html'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.result.markdown, '最新版本：(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://url.wiz.cn/u/windows'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = $Object1.result.markdown | Convert-MarkdownToHtml
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.Version)')]")

      if ($ReleaseNotesTitleNode) {
        try {
          # ReleaseTime
          $ReleaseTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p[1]')
          $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseTimeNode.InnerText, '(\d{4}-\d{2}-\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

          $ReleaseNotesNodes = for ($Node = $ReleaseTimeNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
        } catch {
          $_ | Out-Host
          $this.Log($_, 'Warning')

          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
