$this.CurrentState = Invoke-RestMethod -Uri "https://cdn.apifox.cn/download/latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object1 = Invoke-WebRequest -Uri 'https://apifox.com/help/app/changelog/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object1.SelectSingleNode("//*[contains(@class, 'theme-doc-markdown')]/h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::ul[1]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
