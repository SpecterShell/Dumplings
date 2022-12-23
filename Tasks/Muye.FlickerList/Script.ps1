$Prefix = 'https://static.vifird.com/flicker/download/release/win32_x32/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    $Object1 = Invoke-WebRequest -Uri 'https://flicker.cool/en/versions' | ConvertFrom-Html

    try {
      # ReleaseNotes (en-US)
      $ReleaseNotesNode = $Object1.SelectSingleNode("//*[@id='app']/div/div/div[1]/ul/el-timeline-item[contains(./h2/text()[1],'$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div') | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes (en-US) for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    $Object2 = Invoke-WebRequest -Uri 'https://flicker.cool/versions' | ConvertFrom-Html

    try {
      # ReleaseNotes (zh-CN)
      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@id='app']/div/div/div[1]/ul/el-timeline-item[contains(./h2/text()[1],'$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div') | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes (zh-CN) for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
