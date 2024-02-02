$Prefix = 'https://static.vifird.com/flicker/download/release/win32_x32/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object1 = Invoke-WebRequest -Uri 'https://flicker.cool/en/versions' | ConvertFrom-Html

      # ReleaseTime
      $this.CurrentState.ReleaseTime ??= $Object1.SelectSingleNode('.//*[@class="time"]').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

      $ReleaseNotesNode = $Object1.SelectSingleNode("//*[@class='el-timeline-item' and contains(.//*[@class='version'], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//*[@class="el-card__body"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://flicker.cool/versions' | ConvertFrom-Html

      # ReleaseTime
      $this.CurrentState.ReleaseTime ??= $Object2.SelectSingleNode('.//*[@class="time"]').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@class='el-timeline-item' and contains(.//*[@class='version'], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//*[@class="el-card__body"]') | Get-TextContent | Format-Text
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
