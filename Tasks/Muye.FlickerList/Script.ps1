$Prefix = 'https://static.vifird.com/flicker/download/release/win32_x32/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object1 = Invoke-WebRequest -Uri 'https://flicker.cool/en/versions' | ConvertFrom-Html

    try {
      # ReleaseTime
      $Task.CurrentState.ReleaseTime ??= $Object1.SelectSingleNode('.//*[@class="time"]').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $ReleaseNotesNode = $Object1.SelectSingleNode("//*[@class='el-timeline-item' and contains(.//*[@class='version'], '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//*[@class="el-card__body"]') | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes (en-US) for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Object2 = Invoke-WebRequest -Uri 'https://flicker.cool/versions' | ConvertFrom-Html

    try {
      # ReleaseTime
      $Task.CurrentState.ReleaseTime ??= $Object2.SelectSingleNode('.//*[@class="time"]').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (zh-CN)
      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@class='el-timeline-item' and contains(.//*[@class='version'], '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//*[@class="el-card__body"]') | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes (zh-CN) for version $($Task.CurrentState.Version)", 'Warning')
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
