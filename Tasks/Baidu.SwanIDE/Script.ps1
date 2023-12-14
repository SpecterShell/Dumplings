$Object1 = Invoke-RestMethod -Uri 'https://smartprogram.baidu.com/mappconsole/api/devToolDownloadInfo?system=windows&type=online'

# Version
$Task.CurrentState.Version = $Object1.data.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.download_url | ConvertTo-UnescapedUri
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = ((Invoke-RestMethod -Uri 'https://smartprogram.baidu.com/forum/api/docs_detail?path=%2Fdevelop%2Fdevtools%2Fuplog_tool_normal').data.content.body | ConvertFrom-Markdown).Html | ConvertFrom-Html

    try {
      $ReleaseNotesNode = $Object2.SelectSingleNode("/table/tbody/tr[contains(./td[1]/text(), '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesNode.SelectSingleNode('./td[2]').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./td[3]') | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseTime and ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
