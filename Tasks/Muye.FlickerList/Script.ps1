$Prefix = 'https://static.vifird.com/flicker/download/release/win32_x32/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Object1 = Invoke-WebRequest -Uri 'https://flicker.cool/en/versions' | ConvertFrom-Html

    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime ??= $Object1.SelectSingleNode('.//*[@class="time"]').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $ReleaseNotesNode = $Object1.SelectSingleNode("//*[@class='el-timeline-item' and contains(.//*[@class='version'], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//*[@class="el-card__body"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $this.Logging($_, 'Warning')
    }

    $Object2 = Invoke-WebRequest -Uri 'https://flicker.cool/versions' | ConvertFrom-Html

    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime ??= $Object2.SelectSingleNode('.//*[@class="time"]').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (zh-CN)
      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@class='el-timeline-item' and contains(.//*[@class='version'], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//*[@class="el-card__body"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
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
