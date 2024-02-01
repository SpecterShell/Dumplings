$Object1 = Invoke-RestMethod -Uri 'https://api.live.bilibili.com/xlive/app-blink/v1/liveVersionInfo/getHomePageLiveVersion?system_version=2'

# Version
$this.CurrentState.Version = $Object1.data.curr_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.download_url
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.instruction | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = Invoke-RestMethod -Uri 'https://api.live.bilibili.com/client/v1/LiveHime/getVerList?type=3'

      $ReleaseNotesObject = $Object2.data.list.Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesObject[0].title, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $this.Logging("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
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
