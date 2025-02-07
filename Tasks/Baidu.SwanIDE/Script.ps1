$Object1 = Invoke-RestMethod -Uri 'https://smartprogram.baidu.com/mappconsole/api/devToolDownloadInfo?system=windows&type=online'

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://smartprogram.baidu.com/forum/api/docs_detail?path=%2Fdevelop%2Fdevtools%2Fuplog_tool_normal').data.content.body | Convert-MarkdownToHtml

      $ReleaseNotesNode = $Object2.SelectSingleNode("/table/tbody/tr[contains(./td[1]/text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesNode.SelectSingleNode('./td[2]').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./td[3]') | Get-TextContent | Format-Text
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
