$Task.CurrentState = Invoke-RestMethod -Uri "https://cdn.apifox.cn/download/latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object = Invoke-WebRequest -Uri 'https://apifox.com/help/app/changelog/' | ConvertFrom-Html

    try {
      # ReleaseNotes (zh-CN)
      $ReleaseNotesTitleNode = $Object.SelectSingleNode("//*[contains(@class, 'theme-doc-markdown')]/h2[contains(text(), '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::ul[1]') | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
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
