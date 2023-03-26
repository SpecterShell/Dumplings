$Task.CurrentState = Invoke-RestMethod -Uri "https://cdn.apifox.cn/download/latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object = Invoke-WebRequest -Uri 'https://www.apifox.cn/help/app/changelog/' | ConvertFrom-Html

    try {
      # ReleaseNotes (zh-CN)
      $ReleaseNotesTitleNode = $Object.SelectSingleNode("//main/div/div/h2[contains(text(),'$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::ul[1]') | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
